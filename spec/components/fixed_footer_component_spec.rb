# frozen_string_literal: true

RSpec.describe FixedFooterComponent, type: :component do
  subject(:rendered) do
    render_inline(described_class.new(**options)) do |footer|
      footer.with_action { 'Annuler' }
      footer.with_action { 'Enregistrer' }
      'Enregistré'
    end
  end

  let(:options) { {} }

  it 'renders the actions as a button group, then the content, in a padded fixed bar' do
    is_expected.to have_css('.padded-fixed-footer .fixed-footer .fr-container .fr-col-12')
    is_expected.to have_css('ul.fr-btns-group.fr-btns-group--inline-md:not(.fr-btns-group--center) > li', count: 2)
    is_expected.to have_css('li:first-child', text: 'Annuler')
    is_expected.to have_css('.fr-col-12', text: 'Enregistré')
    is_expected.to have_no_css('.fr-col-offset-md-2')
  end

  context 'centered, narrow, with extra classes' do
    let(:options) { { centered: true, narrow: true, extra_class_names: 'dossier-edit-footer' } }

    it do
      is_expected.to have_css('.padded-fixed-footer.dossier-edit-footer')
      is_expected.to have_css('.fr-col-12.fr-col-offset-md-2.fr-col-md-8')
      is_expected.to have_css('ul.fr-btns-group--center')
    end
  end

  context 'without actions' do
    subject(:rendered) { render_inline(described_class.new) { 'Nouveau message' } }

    it do
      is_expected.to have_no_css('ul')
      is_expected.to have_css('.fixed-footer', text: 'Nouveau message')
    end
  end
end
