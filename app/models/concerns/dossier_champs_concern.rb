# frozen_string_literal: true

module DossierChampsConcern
  extend ActiveSupport::Concern

  def champs_for_revision(scope: nil)
    champs_index = main_stream.group_by(&:stable_id)
    revision.types_de_champ_for(scope:)
      .flat_map { champs_index[_1.stable_id] || [] }
  end

  # Get all the champs values for the types de champ in the final list.
  # Dossier might not have corresponding champ – display nil.
  # To do so, we build a virtual champ when there is no value so we can call for_export with all indexes
  def champs_for_export(types_de_champ, row_id = nil)
    types_de_champ.flat_map do |type_de_champ|
      champ = champ_for_export(type_de_champ, row_id)
      type_de_champ.libelles_for_export.map do |(libelle, path)|
        [libelle, TypeDeChamp.champ_value_for_export(type_de_champ.type_champ, champ, path)]
      end
    end
  end

  def project_champ(type_de_champ, row_id, stream: Champ::MAIN_STREAM)
    check_valid_row_id?(type_de_champ, row_id)
    champ = champs_by_public_id(stream)[type_de_champ.public_id(row_id)]
    if champ.nil?
      type_de_champ.build_champ(dossier: self, row_id:, updated_at: depose_at || created_at)
    else
      champ
    end
  end

  def project_champs_public(stream: Champ::MAIN_STREAM)
    revision.types_de_champ_public.map { project_champ(_1, nil, stream:) }
  end

  def project_champs_private(stream: Champ::MAIN_STREAM)
    revision.types_de_champ_private.map { project_champ(_1, nil, stream:) }
  end

  def project_rows_for(type_de_champ)
    [] if !type_de_champ.repetition?

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

  def champ_for_update(type_de_champ, row_id, updated_by:)
    champ, attributes = champ_with_attributes_for_update(type_de_champ, row_id, updated_by:)
    champ.assign_attributes(attributes)
    champ
  end

  def update_champs_attributes(attributes, scope, updated_by:)
    champs_attributes = attributes.to_h.map do |public_id, attributes|
      champ_attributes_by_public_id(public_id, attributes, scope, updated_by:)
    end

    assign_attributes(champs_attributes:)
  end

  def repetition_row_ids(type_de_champ)
    [] if !type_de_champ.repetition?

    stable_ids = revision.children_of(type_de_champ).map(&:stable_id)
    champs.filter { _1.stable_id.in?(stable_ids) && _1.row_id.present? }
      .map(&:row_id)
      .uniq
      .sort
  end

  def repetition_add_row(type_de_champ, updated_by:, stream: Champ::MAIN_STREAM)
    raise "Can't add row to non-repetition type de champ" if !type_de_champ.repetition?

    row_id = ULID.generate
    types_de_champ = revision.children_of(type_de_champ)
    # TODO: clean this up when parent_id is deprecated
    added_champs = types_de_champ.map { _1.build_champ(row_id:, updated_by:) }
    reset_champs_cache
    [row_id, added_champs]
  end

  def repetition_remove_row(type_de_champ, row_id, updated_by:, stream: Champ::MAIN_STREAM)
    raise "Can't remove row from non-repetition type de champ" if !type_de_champ.repetition?

    champs.where(row_id:).destroy_all
    champs.reload if persisted?
    reset_champs_cache
  end

  def reload
    super.tap { reset_champs_cache }
  end

  def merge_stream(stream)
    case stream
    when Champ::USER_DRAFT_STREAM
      merge_user_draft_stream
    else
      raise ArgumentError, "Invalid stream: #{stream}"
    end

    reload_champs_cache
  end

  def reset_stream(stream)
    case stream
    when Champ::USER_DRAFT_STREAM
      champs.where(stream:).delete_all
    else
      raise ArgumentError, "Invalid stream: #{stream}"
    end

    reload_champs_cache
  end

  def main_stream
    champs.filter(&:main_stream?)
  end

  def user_draft_stream
    champs.filter(&:user_draft_stream?)
  end

  def history_stream
    champs.filter(&:history_stream?)
  end

  def user_draft_changes?
    user_draft_stream.present?
  end

  def user_draft_changes_on_champ?(champ)
    if user_draft_changes?
      user_draft_stream.any? { _1.public_id == champ.public_id }
    end
  end

  private

  def merge_user_draft_stream
    draft_champs = champs.where(stream: Champ::USER_DRAFT_STREAM)
      .pluck(:id, :stable_id, :row_id)
      .index_by { |(_, stable_id, row_id)| [stable_id, row_id].compact }
      .transform_values(&:first)

    main_champs = champs.where(stream: Champ::MAIN_STREAM)
      .pluck(:id, :stable_id, :row_id)
      .index_by { |(_, stable_id, row_id)| [stable_id, row_id].compact }
      .transform_values(&:first)

    draft_champ_ids = draft_champs.values
    main_champ_ids = main_champs.filter_map do |key, id|
      id if draft_champs.key?(key)
    end

    now = Time.zone.now
    transaction do
      champs.where(id: main_champ_ids, stream: Champ::MAIN_STREAM).update_all(stream: "#{Champ::HISTORY_STREAM}#{now}")
      champs.where(id: draft_champ_ids, stream: Champ::USER_DRAFT_STREAM).update_all(stream: Champ::MAIN_STREAM, updated_at: now)
    end

    reload_champs_cache
  end

  def champs_by_public_id(stream = Champ::MAIN_STREAM)
    case stream
    when Champ::MAIN_STREAM
      @champs_by_public_id ||= main_stream.sort_by(&:updated_at).index_by(&:public_id)
    when Champ::USER_DRAFT_STREAM
      @draft_user_champs_by_public_id ||= user_draft_stream.sort_by(&:updated_at).index_by(&:public_id)
    end
  end

  def champ_for_export(type_de_champ, row_id)
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
    check_valid_row_id?(type_de_champ, row_id)

    stream = if type_de_champ.public? && use_streams?
      Champ::USER_DRAFT_STREAM
    else
      Champ::MAIN_STREAM
    end

    attributes = type_de_champ.params_for_champ
    attributes[:stream] = stream

    draft_stream_champ = if stream != Champ::MAIN_STREAM
      champs.exists?(stable_id: type_de_champ.stable_id, row_id:, stream:)
    end
    main_stream_champ = if stream != Champ::MAIN_STREAM && !draft_stream_champ
      champs.find_by(stable_id: type_de_champ.stable_id, row_id:, stream: Champ::MAIN_STREAM)
    end

    # TODO: Once we have the right index in place, we should change this to use `create_or_find_by` instead of `find_or_create_by`
    champ = champs
      .create_with(**attributes)
      .find_or_create_by!(stable_id: type_de_champ.stable_id, row_id:, stream:)

    attributes[:id] = champ.id
    attributes[:updated_by] = updated_by

    # Needed when a revision change the champ type in this case, we reset the champ data
    if champ.type != attributes[:type]
      attributes[:value] = nil
      attributes[:value_json] = nil
      attributes[:external_id] = nil
      attributes[:data] = nil
    elsif main_stream_champ.present?
      champ.clone_value_from(main_stream_champ)
    end

    parent = revision.parent_of(type_de_champ)
    if parent.present?
      attributes[:parent] = champs.find { _1.stable_id == parent.stable_id }
    else
      attributes[:parent] = nil
    end

    reset_champs_cache

    [champ, attributes]
  end

  def check_valid_row_id?(type_de_champ, row_id)
    if type_de_champ.child?(revision)
      if row_id.blank?
        raise "type_de_champ #{type_de_champ.stable_id} in revision #{revision_id} must have a row_id because it is part of a repetition"
      end
    elsif row_id.present? && type_de_champ.in_revision?(revision)
      raise "type_de_champ #{type_de_champ.stable_id} in revision #{revision_id} can not have a row_id because it is not part of a repetition"
    end
  end

  def use_streams?
    procedure.feature_enabled?(:user_draft_stream) && en_construction? && editing_forks.empty?
  end

  def reset_champs_cache
    @champs_by_public_id = nil
    @draft_user_champs_by_public_id = nil
  end

  def reload_champs_cache
    champs.reload
    reset_champs_cache
  end
end
