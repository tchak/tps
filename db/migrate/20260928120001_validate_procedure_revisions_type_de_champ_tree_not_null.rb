# frozen_string_literal: true

class ValidateProcedureRevisionsTypeDeChampTreeNotNull < ActiveRecord::Migration[8.1]
  def change
    validate_check_constraint :procedure_revisions, name: "procedure_revisions_type_de_champ_tree_null"
  end
end
