# frozen_string_literal: true

describe 'layouts/application', type: :view do
  let(:procedure) { procedures.individual }

  before do
    allow(view).to receive(:administrateur_signed_in?).and_return(false)
    allow(view).to receive(:instructeur_signed_in?).and_return(false)
    allow(view).to receive(:user_signed_in?).and_return(false)
    allow(view).to receive(:chatbot_disabled_page?).and_return(false)
    allow(view).to receive(:extra_query_params).and_return({})
    view.content_for(:footer, "footer")
  end

  subject { render html: '', layout: 'layouts/application' }

  def title_text
    Nokogiri::HTML(subject).at("title")&.text&.strip
  end

  context "without content_for(:title) or @procedure" do
    it "does not include a separator in the title" do
      expect(title_text).not_to include("·")
    end
  end

  context "with content_for(:title) set" do
    before { view.content_for(:title, "Custom title") }

    it "displays the custom title" do
      expect(title_text).to include("Custom title")
    end
  end

  context "with @procedure and no content_for(:title)" do
    before { assign(:procedure, procedure) }

    it "includes the procedure id" do
      expect(title_text).to include("##{procedure.id}")
    end

    it "includes the procedure libelle" do
      expect(title_text).to include(procedure.libelle)
    end
  end

  context "with both @procedure and content_for(:title) set" do
    before do
      assign(:procedure, procedure)
      view.content_for(:title, "Specific title")
    end

    it "includes both the custom title and the procedure info" do
      expect(title_text).to include("Specific title")
      expect(title_text).to include("##{procedure.id}")
    end
  end

  context "with @procedure whose libelle contains HTML" do
    let(:procedure) { create(:simple_procedure, libelle: "<script>xss</script>") }

    before { assign(:procedure, procedure) }

    it "escapes the libelle in the title" do
      expect(title_text).not_to include("<script>")
    end
  end
end
