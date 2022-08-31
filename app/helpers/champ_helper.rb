module ChampHelper
  def has_label?(champ)
    types_without_label = [TypeDeChamp.type_champs.fetch(:header_section), TypeDeChamp.type_champs.fetch(:explication)]
    !types_without_label.include?(champ.type_champ)
  end

  def champ_carte_params(champ)
    if champ.persisted?
      { champ_id: champ.id }
    else
      { type_de_champ_id: champ.type_de_champ_id }
    end
  end

  def format_text_value(text)
    sanitized_text = sanitize(text)
    auto_linked_text = Anchored::Linker.auto_link(sanitized_text, target: '_blank', rel: 'noopener') do |link_href|
      truncate(link_href, length: 60)
    end
    simple_format(auto_linked_text, {}, sanitize: false)
  end

  def auto_attach_url(object)
    if object.is_a?(Champ)
      champs_piece_justificative_url(object.id)
    elsif object.is_a?(TypeDeChamp)
      piece_justificative_template_admin_procedure_type_de_champ_url(stable_id: object.stable_id, procedure_id: object.procedure.id)
    end
  end

  def autosave_available?(champ)
    # FIXME: enable autosave on champs private? once we figured out how to batch audit events
    champ.dossier.brouillon? && !champ.repetition?
  end

  def editable_champ_controller(champ)
    if !champ.repetition? && !champ.non_fillable?
      # This is an editable champ. Lets find what controllers it might need.
      controllers = []

      # This is a public champ – it can have an autosave controller.
      if champ.public?
        # This is a champ on dossier in draft state. Activate autosave.
        if champ.dossier.brouillon?
          controllers << 'autosave'
        # This is a champ on a dossier in en_construction state. Enable conditions checker.
        elsif champ.public? && champ.dossier.en_construction?
          controllers << 'check-conditions'
        end
      end

      # This is a dropdown champ. Activate special behaviours it might have.
      if champ.simple_drop_down_list? || champ.linked_drop_down_list?
        controllers << 'champ-dropdown'
      end

      if controllers.present?
        { controller: controllers.join(' ') }
      end
    end
  end
end
