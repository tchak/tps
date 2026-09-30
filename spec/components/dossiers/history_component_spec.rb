# frozen_string_literal: true

RSpec.describe Dossiers::HistoryComponent, type: :component do
  subject { render_inline(described_class.new(dossier:)) }

  let(:dossier) do
    create(:dossier, :en_construction,
      depose_at: Time.zone.local(2025, 3, 20, 16, 22),
      last_champ_updated_at: Time.zone.local(2025, 3, 20, 18, 15),
      en_instruction_at: Time.zone.local(2026, 4, 15),
      last_champ_instructeur_updated_at: Time.zone.local(2026, 7, 8, 16, 32))
  end

  before { create(:dossier_correction, dossier:, created_at: Time.zone.local(2026, 6, 24, 13, 53)) }

  it 'lists the events from the oldest to the most recent' do
    expect(subject.css('li').map { it.text.squish }).to eq([
      'Déposé le 20 mars 2025 à 16:22',
      'Modifié par l’usager le 20 mars 2025 à 18:15',
      'Passé en instruction le 15 avril 2026 à 00:00',
      'Correction demandée le 24 juin 2026 à 13:53',
      'Modifié par l’instructeur le 08 juillet 2026 à 16:32',
    ])
  end
end
