# frozen_string_literal: true

class Dossiers::HistoryComponent < ApplicationComponent
  attr_reader :dossier

  def initialize(dossier:)
    @dossier = dossier
  end

  def events
    events = [event(dossier.depose_at) { t('views.shared.dossiers.form.submitted_at', datetime: it) }]

    if dossier.last_champ_updated_at.present? && dossier.last_champ_updated_at > dossier.depose_at
      events << event(dossier.last_champ_updated_at) { t('views.shared.dossiers.form.user_updated_at', datetime: it) }
    end

    if dossier.last_champ_instructeur_updated_at.present?
      events << event(dossier.last_champ_instructeur_updated_at) { t('views.shared.dossiers.form.instructeur_updated_at', datetime: it) }
    end

    if dossier.en_instruction_at.present?
      events << event(dossier.en_instruction_at) { t('views.shared.dossiers.form.switched_to_instruction_at', datetime: it) }
    end

    if dossier.pending_correction?
      events << event(dossier.pending_correction.created_at) { t('views.shared.dossiers.form.revert_to_submitted_at', datetime: it) }
    end

    if dossier.termine?
      events << event(dossier.processed_at) { decision(it) }
    end

    events.sort_by(&:first).map(&:last)
  end

  private

  def event(datetime)
    [datetime, yield(l(datetime, format: :long_with_time))]
  end

  def decision(datetime)
    if dossier.accepte?
      t('views.shared.dossiers.form.acceptee_at', datetime:)
    elsif dossier.refuse?
      t('views.shared.dossiers.form.refuse_at', datetime:)
    elsif dossier.sans_suite?
      t('views.shared.dossiers.form.closed_at', datetime:)
    end
  end
end
