# frozen_string_literal: true

RSpec.describe Procedure::FixedFooterComponent, type: :component do
  let(:procedure) { procedures.individual }

  context 'without a form' do
    subject(:rendered) { render_inline(described_class.new(procedure:)) { 'Aperçu' } }

    it 'links back to the procedure page, followed by the content' do
      is_expected.to have_link('Revenir à l’écran de gestion', href: "/admin/procedures/#{procedure.id}")
      is_expected.to have_css('.fixed-footer', text: 'Aperçu')
      is_expected.to have_no_css('ul.fr-btns-group')
    end
  end

  context 'with a form' do
    subject(:rendered) do
      render_inline(described_class.new(procedure:, form:, is_form_disabled: true, narrow: true))
    end

    let(:form) { ActionView::Helpers::FormBuilder.new(:procedure, procedure, vc_test_controller.view_context, {}) }

    it 'cancels, then saves' do
      is_expected.to have_css('.fr-col-md-8 ul.fr-btns-group > li:first-child a.fr-btn--secondary', text: 'Annuler et revenir à l’écran de gestion')
      is_expected.to have_css('li:last-child input[type=submit][value="Enregistrer"][disabled]')
    end
  end
end
