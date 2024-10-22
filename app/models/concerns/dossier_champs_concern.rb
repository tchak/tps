# frozen_string_literal: true

module DossierChampsConcern
  extend ActiveSupport::Concern

  def project_champ(type_de_champ, row_id)
    check_valid_row_id?(type_de_champ, row_id)
    champ = champs_by_public_id[type_de_champ.public_id(row_id)]
    if champ.nil? || !champ.same_type?(type_de_champ.type_champ)
      type_de_champ.build_champ(dossier: self, row_id:,
        updated_at: champ&.updated_at || depose_at || created_at,
        rebased_at: champ&.rebased_at,
        value: (champ.nil? || TypeDeChamp.use_default_value?(type_de_champ.type_champ, champ)) ? nil : champ.value)
    else
      champ
    end
  end

  def project_champs_public
    revision.types_de_champ_public.map { project_champ(_1, nil) }
  end

  def project_champs_private
    revision.types_de_champ_private.map { project_champ(_1, nil) }
  end

  def filled_champs_public
    project_champs_public.flat_map do |champ|
      if champ.repetition?
        champ.rows.flatten.filter { _1.persisted? && _1.fillable? }
      elsif champ.persisted? && champ.fillable?
        champ
      else
        []
      end
    end
  end

  def filled_champs_private
    project_champs_private.flat_map do |champ|
      if champ.repetition?
        champ.rows.flatten.filter { _1.persisted? && _1.fillable? }
      elsif champ.persisted? && champ.fillable?
        champ
      else
        []
      end
    end
  end

  def filled_champs
    filled_champs_public + filled_champs_private
  end

  def project_rows_for(type_de_champ)
    return [] if !type_de_champ.repetition?

    children = revision.children_of(type_de_champ)
    row_ids = repetition_row_ids(type_de_champ)

    row_ids.map do |row_id|
      children.map { project_champ(_1, row_id) }
    end
  end

  def find_type_de_champ_by_stable_id(stable_id, scope = nil)
    case scope
    when :public
      revision.types_de_champ.public_only
    when :private
      revision.types_de_champ.private_only
    else
      revision.types_de_champ
    end.find_by!(stable_id:)
  end

  def champs_for_prefill(stable_ids)
    revision
      .types_de_champ
      .filter { _1.stable_id.in?(stable_ids) }
      .filter { !_1.child?(revision) }
      .map { _1.repetition? ? project_champ(_1, nil) : champ_for_update(_1, nil, updated_by: nil) }
  end

  def champs_for_export(types_de_champ, row_id = nil)
    types_de_champ.flat_map do |type_de_champ|
      champ = filled_champ(type_de_champ, row_id)
      type_de_champ.libelles_for_export.map do |(libelle, path)|
        [libelle, type_de_champ.champ_value_for_export(champ, path)]
      end
    end
  end

  def champ_value_for_tag(type_de_champ, path = :value)
    champ = filled_champ(type_de_champ, nil)
    type_de_champ.champ_value_for_tag(champ, path)
  end

  def champ_for_update(type_de_champ, row_id, updated_by:, &block)
    champ, attributes = champ_with_attributes_for_update(type_de_champ, row_id, updated_by:)
    champ.assign_attributes(attributes)
    if block_given?
      yield champ
      champs_by_public_id[champ.public_id]&.reload
    end
    champ
  end

  def update_champs_attributes(attributes, scope, updated_by:)
    champs_attributes = attributes.to_h.map do |public_id, attributes|
      champ_attributes_by_public_id(public_id, attributes, scope, updated_by:)
    end

    assign_attributes(champs_attributes:)
  end

  def repetition_rows_for_export(type_de_champ)
    repetition_row_ids(type_de_champ).map.with_index(1) do |row_id, index|
      Champs::RepetitionChamp::Row.new(index:, row_id:, dossier: self)
    end
  end

  def repetition_row_ids(type_de_champ)
    return [] if !type_de_champ.repetition?

    rows = champs.filter { _1.stable_id == type_de_champ.stable_id && _1.row_id.present? }
    row_ids = rows.reject(&:discarded?).map(&:row_id)

    # Legacy rows are rows that have been created before the introduction of the discarded_at column
    # TODO migrate and clean
    children_stable_ids = revision.children_of(type_de_champ).map(&:stable_id)
    discarded_row_ids = rows.filter(&:discarded?).map(&:row_id)
    legacy_row_ids = champs.filter { _1.stable_id.in?(children_stable_ids) && _1.row_id.present? }.map(&:row_id).uniq
    row_ids += (legacy_row_ids - discarded_row_ids)

    row_ids.uniq.sort
  end

  def repetition_add_row(type_de_champ, updated_by:)
    raise "Can't add row to non-repetition type de champ" if !type_de_champ.repetition?

    row_id = ULID.generate
    champ_for_update(type_de_champ, row_id, updated_by:, &:save!)
    row_id
  end

  def repetition_remove_row(type_de_champ, row_id, updated_by:)
    raise "Can't remove row from non-repetition type de champ" if !type_de_champ.repetition?

    champ_for_update(type_de_champ, row_id, updated_by:, &:discard!)
  end

  def reload
    super.tap do
      @champs_by_public_id = nil
    end
  end

  private

  def champs_by_public_id
    @champs_by_public_id ||= champs.sort_by(&:id).index_by(&:public_id)
  end

  def filled_champ(type_de_champ, row_id)
    champ = champs_by_public_id[type_de_champ.public_id(row_id)]
    if champ.blank? || !champ.visible?
      nil
    else
      champ
    end
  end

  def champ_attributes_by_public_id(public_id, attributes, scope, updated_by:)
    stable_id, row_id = public_id.split('-')
    type_de_champ = find_type_de_champ_by_stable_id(stable_id, scope)
    champ_with_attributes_for_update(type_de_champ, row_id, updated_by:).last.merge(attributes)
  end

  def champ_with_attributes_for_update(type_de_champ, row_id, updated_by:)
    check_valid_row_id?(type_de_champ, row_id, write: true)
    attributes = type_de_champ.params_for_champ
    # TODO: Once we have the right index in place, we should change this to use `create_or_find_by` instead of `find_or_create_by`
    champ = champs
      .create_with(**attributes)
      .find_or_create_by!(stable_id: type_de_champ.stable_id, row_id:)

    attributes[:id] = champ.id
    attributes[:updated_by] = updated_by

    # Needed when a revision change the champ type in this case, we reset the champ data
    if champ.type != attributes[:type]
      attributes[:value] = nil
      attributes[:value_json] = nil
      attributes[:external_id] = nil
      attributes[:data] = nil
    end

    @champs_by_public_id = nil

    [champ, attributes]
  end

  def check_valid_row_id?(type_de_champ, row_id, write: false)
    if type_de_champ.repetition? && write
      if row_id.blank?
        raise "type_de_champ #{type_de_champ.stable_id} in revision #{revision_id} must have a row_id because it represents a row in a repetition"
      end
    elsif type_de_champ.child?(revision)
      if row_id.blank?
        raise "type_de_champ #{type_de_champ.stable_id} in revision #{revision_id} must have a row_id because it is part of a repetition"
      end
    elsif row_id.present? && type_de_champ.in_revision?(revision)
      raise "type_de_champ #{type_de_champ.stable_id} in revision #{revision_id} can not have a row_id because it is not part of a repetition"
    end
  end
end
