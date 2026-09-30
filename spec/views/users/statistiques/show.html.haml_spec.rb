# frozen_string_literal: true

describe 'users/statistiques/show', type: :view do
  let(:procedure) { create(:procedure) }

  before do
    assign(:procedure, procedure)
  end

  subject { render }

  it "display stats" do
    expect(subject).to have_text("Répartition par semaine")
    expect(subject).to have_text("Avancée des dossiers")
    expect(subject).to have_text("Taux d’acceptation")
    expect(subject).to have_text(procedure.libelle)
  end

  it 'does not show the user indication mention' do
    expect(subject).not_to have_text("indiqué aux usagers")
  end

  context 'with dossiers terminés in the last weeks' do
    before do
      assign(:termines_by_week, [
        { name: 'accepte', data: { '06 avr.' => 0, '13 avr.' => 2, '20 avr.' => 0 } },
        { name: 'refuse', data: { '06 avr.' => 0, '13 avr.' => 0, '20 avr.' => 1 } },
      ])
    end

    it 'names, colours and layers each weekly series after its state' do
      render
      expect(view.content_for(:charts_js)).to include('"name":"Refusé"')
      expect(view.content_for(:charts_js)).to include('"color":"var(--background-flat-error)"')
      expect(view.content_for(:charts_js)).to include('"color":"var(--background-flat-success)","zIndex":2')
    end
  end
end
