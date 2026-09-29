# frozen_string_literal: true

class AddDefaultToProcedureRevisionsTypeDeChampTree < ActiveRecord::Migration[8.1]
  def up
    change_column_default :procedure_revisions, :type_de_champ_tree, from: nil, to: { public_children: [], private_children: [] }

    # Production has none since T20260918BackfillProcedureRevisionTypeDeChampTreeTask
    # ran; a development database may.
    safety_assured { execute("UPDATE procedure_revisions SET type_de_champ_tree = DEFAULT WHERE type_de_champ_tree IS NULL") }

    add_check_constraint :procedure_revisions, "type_de_champ_tree IS NOT NULL", name: "procedure_revisions_type_de_champ_tree_null", validate: false
  end

  def down
    remove_check_constraint :procedure_revisions, name: "procedure_revisions_type_de_champ_tree_null"
    change_column_default :procedure_revisions, :type_de_champ_tree, from: { public_children: [], private_children: [] }, to: nil
  end
end
