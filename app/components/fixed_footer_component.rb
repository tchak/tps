# frozen_string_literal: true

# Action bar pinned to the bottom of the viewport. Its wrapper reserves the bar's
# height at the end of the page, so the bar never hides the last lines of content.
# Actions are rendered as a DSFR button group; anything else (a back link, an
# autosave notice, a message form) goes in the content, after the actions.
class FixedFooterComponent < ApplicationComponent
  renders_many :actions

  # narrow: aligns the bar with a form laid out on the 8 centered columns.
  def initialize(centered: false, narrow: false, extra_class_names: nil)
    @centered = centered
    @narrow = narrow
    @extra_class_names = extra_class_names
  end

  private

  def column_class_names
    class_names('fr-col-12', 'fr-col-offset-md-2 fr-col-md-8' => @narrow)
  end

  def actions_class_names
    class_names('fr-btns-group fr-btns-group--inline-md', 'fr-btns-group--center' => @centered)
  end
end
