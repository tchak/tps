# frozen_string_literal: true

class TypesDeChamp::RepetitionTypeDeChamp < TypesDeChamp::TypeDeChampBase
  def champ_value_for_tag(champ, path = :value)
    return nil if path != :value
    return champ_default_value if champ_value_blank?(champ)

    ChampPresentations::RepetitionPresentation.new(libelle, champ.dossier.project_rows_for(@type_de_champ))
  end

  def estimated_fill_duration(revision)
    estimated_rows_in_repetition = 2.5

    children = revision.children_of(@type_de_champ)

    estimated_row_duration = children.map { _1.estimated_fill_duration(revision) }.sum
    estimated_children_read_duration = children.map(&:estimated_read_duration).sum

    # Count only once children read time for all rows
    estimated_row_duration * estimated_rows_in_repetition + estimated_children_read_duration
  end

  # We have to truncate the label here as spreadsheets have a (30 char) limit on length.
  def libelle_for_export
    str = "(#{stable_id}) #{libelle}"
    # /\*?[] are invalid Excel worksheet characters
    ActiveStorage::Filename.new(str.delete('[]*?')).sanitized
  end

  def champ_value_blank?(champ)
    champ.dossier.repetition_row_ids(@type_de_champ).blank?
  end

  def columns(procedure_id:, displayable: true, prefix: nil)
    @type_de_champ.procedure
      .all_revisions_types_de_champ(parent: @type_de_champ)
      .flat_map { _1.columns(procedure_id:, displayable: false, prefix: libelle) }
  end
end
