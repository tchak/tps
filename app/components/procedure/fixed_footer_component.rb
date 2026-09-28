# frozen_string_literal: true

# The fixed footer of the procedure settings pages: cancel and save with a form,
# a link back to the procedure page otherwise, followed by the content (a
# preview link, an autosave notice).
class Procedure::FixedFooterComponent < ApplicationComponent
  def initialize(procedure:, form: nil, is_form_disabled: nil, narrow: false)
    @procedure = procedure
    @form = form
    @is_form_disabled = is_form_disabled
    @narrow = narrow
  end

  attr_reader :form, :is_form_disabled
end
