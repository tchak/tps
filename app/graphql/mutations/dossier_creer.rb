module Mutations
  class DossierCreer < Mutations::BaseMutation
    description "Créer un dossier."

    class ChampValueInput < Types::BaseInputObject
      one_of
      argument :string, String, required: false
      argument :strings, [String], required: false
      argument :bool, Boolean, required: false
      argument :int, Int, required: false
      argument :float, Float, required: false
      argument :date, GraphQL::Types::ISO8601Date, required: false
      argument :datetime, GraphQL::Types::ISO8601DateTime, required: false
      argument :files, [ID], required: false
    end

    class ChampInput < Types::BaseInputObject
      argument :id, ID, required: true
      argument :value, ChampValueInput, required: true
      argument :row, Int, required: false
    end

    argument :demarche, Types::DemarcheDescriptorType::FindDemarcheInput, "Démarche.", required: true
    argument :draft, Boolean, "Créer un dossier de test.", required: false, default_value: false

    argument :champs, [ChampInput], required: true

    field :dossier_url, String, null: true
    field :errors, [Types::ValidationErrorType], null: true

    def resolve(demarche:, champs:, draft:)
      demarche_number = demarche.number.presence || ApplicationRecord.id_from_typed_id(demarche.id)
      demarche = Procedure.find(demarche_number)

      if demarche.present? && (demarche.opendata? || context.authorized_demarche?(demarche))
        attributes = champs_attributes(demarche, champs)

        errors = attributes.filter { _1[:error].present? }.map { _1[:error] }
        return { errors: errors } if errors.present?

        dossier = Dossier.new(
          revision: draft ? demarche.draft_revision : demarche.active_revision,
          groupe_instructeur: demarche.defaut_groupe_instructeur_for_new_dossier,
          user: nil,
          state: Dossier.states.fetch(:brouillon)
        )
        dossier.build_default_individual

        champs = dossier.champs_public.index_by(&:stable_id)
        dossier.assign_attributes(champs_public_attributes: attributes.map do |attributes|
          stable_id = attributes.delete(:stable_id)
          attributes.merge(id: champs[stable_id].id)
        end)

        if dossier.save
          { dossier_url: SecureRandom.uuid }
        else
          { errors: dossier.errors.full_messages }
        end
      else
        { errors: ["Démarche non trouvée"] }
      end
    end

    private

    def champs_attributes(demarche, champs)
      champ_inputs_by_id = champs.index_by { ApplicationRecord.id_from_typed_id(_1.id) }
      ids = champ_inputs_by_id.keys
      types_de_champ = demarche.active_revision.types_de_champ_public.where(id: ids)

      types_de_champ.map do |type_de_champ|
        champ_input = champ_inputs_by_id[type_de_champ.stable_id]
        attributes = case type_de_champ.type_champ
        when TypeDeChamp.type_champs.fetch(:checkbox)
          if champ_input.value.bool.present?
            { value: champ_input.value.bool ? 'on' : 'off' }
          else
            { error: "#{type_de_champ.libelle} est invalid" }
          end
        when TypeDeChamp.type_champs.fetch(:yes_no)
          if champ_input.value.bool.present?
          { value: champ_input.value.bool ? 'true' : 'false' }
          else
            { error: "#{type_de_champ.libelle} est invalid" }
          end
        when TypeDeChamp.type_champs.fetch(:date)
          if champ_input.value.date.present?
            { value: champ_input.value.date }
          else
            { error: "#{type_de_champ.libelle} est invalid" }
          end
        when TypeDeChamp.type_champs.fetch(:datetime)
          if champ_input.value.datetime.present?
            { value: champ_input.value.datetime }
          else
            { error: "#{type_de_champ.libelle} est invalid" }
          end
        when TypeDeChamp.type_champs.fetch(:decimal_number)
          if champ_input.value.float.present?
            { value: champ_input.value.float.to_s }
          else
            { error: "#{type_de_champ.libelle} est invalid" }
          end
        when TypeDeChamp.type_champs.fetch(:integer_number)
          if champ_input.value.int.present?
            { value: champ_input.value.int.to_s }
          else
            { error: "#{type_de_champ.libelle} est invalid" }
          end
        when TypeDeChamp.type_champs.fetch(:piece_justificative)
          if champ_input.value.files.present?
            { piece_justificative_file: champ_input.value.files.first }
          else
            { error: "#{type_de_champ.libelle} est invalid" }
          end
        when TypeDeChamp.type_champs.fetch(:multiple_drop_down_list)
          if champ_input.value.strings.present?
            { value: champ_input.value.strings.to_json }
          else
            { error: "#{type_de_champ.libelle} est invalid" }
          end
        else
          if champ_input.value.string.present?
            { value: champ_input.value.string }
          else
            { error: "#{type_de_champ.libelle} est invalid" }
          end
        end
        attributes.merge(stable_id: type_de_champ.stable_id)
      end
    end
  end
end
