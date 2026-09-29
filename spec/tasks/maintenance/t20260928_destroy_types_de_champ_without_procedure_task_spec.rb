# frozen_string_literal: true

require "rails_helper"

module Maintenance
  RSpec.describe T20260928DestroyTypesDeChampWithoutProcedureTask do
    let!(:orphan) { create(:type_de_champ, no_coordinate: true) }
    let!(:orphan_with_template) { create(:type_de_champ_piece_justificative, no_coordinate: true) }
    let!(:laid_out) { procedures.individual.draft_revision.public_root_type_de_champs.first.tap { it.update_column(:procedure_id, nil) } }
    let!(:attached_to_a_procedure) { create(:type_de_champ, no_coordinate: true, procedure: procedures.individual) }

    describe "#collection" do
      subject(:collection) { described_class.collection.flat_map(&:to_a) }

      it "walks the types de champ of no procedure which no revision lays out" do
        expect(collection).to include(orphan, orphan_with_template)
        expect(collection).not_to include(laid_out, attached_to_a_procedure)
      end
    end

    describe "#process" do
      subject(:process) { described_class.process(TypeDeChamp.where(id: [orphan, orphan_with_template])) }

      it "destroys them, along with their attachments" do
        attachments = ActiveStorage::Attachment.where(record_type: 'TypeDeChamp', record_id: orphan_with_template.id)
        expect(attachments).to be_present

        expect { process }.to change { TypeDeChamp.where(id: [orphan, orphan_with_template]).count }.from(2).to(0)

        expect(attachments.reload).to be_empty
      end
    end
  end
end
