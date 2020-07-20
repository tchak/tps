FactoryBot.define do
  factory :champ do
    dossier { association :dossier }
    type_de_champ { association :type_de_champ, procedure: dossier.procedure }

    trait :with_piece_justificative_file do
      after(:build) do |champ, _evaluator|
        champ.piece_justificative_file.attach(io: StringIO.new("toto"), filename: "toto.txt", content_type: "text/plain")
      end
    end

    factory :champ_text, class: 'Champs::TextChamp' do
      type_de_champ { association :type_de_champ_text, procedure: dossier.procedure }
      value { 'text' }
    end

    factory :champ_textarea, class: 'Champs::TextareaChamp' do
      type_de_champ { association :type_de_champ_textarea, procedure: dossier.procedure }
      value { 'textarea' }
    end

    factory :champ_date, class: 'Champs::DateChamp' do
      type_de_champ { association :type_de_champ_date, procedure: dossier.procedure }
      value { '2019-07-10' }
    end

    factory :champ_datetime, class: 'Champs::DatetimeChamp' do
      type_de_champ { association :type_de_champ_datetime, procedure: dossier.procedure }
      value { '15/09/1962 15:35' }
    end

    factory :champ_number, class: 'Champs::NumberChamp' do
      type_de_champ { association :type_de_champ_number, procedure: dossier.procedure }
      value { '42' }
    end

    factory :champ_decimal_number, class: 'Champs::DecimalNumberChamp' do
      type_de_champ { association :type_de_champ_decimal_number, procedure: dossier.procedure }
      value { '42.1' }
    end

    factory :champ_integer_number, class: 'Champs::IntegerNumberChamp' do
      type_de_champ { association :type_de_champ_integer_number, procedure: dossier.procedure }
      value { '42' }
    end

    factory :champ_checkbox, class: 'Champs::CheckboxChamp' do
      type_de_champ { association :type_de_champ_checkbox, procedure: dossier.procedure }
      value { 'on' }
    end

    factory :champ_civilite, class: 'Champs::CiviliteChamp' do
      type_de_champ { association :type_de_champ_civilite, procedure: dossier.procedure }
      value { 'M.' }
    end

    factory :champ_email, class: 'Champs::EmailChamp' do
      type_de_champ { association :type_de_champ_email, procedure: dossier.procedure }
      value { 'yoda@beta.gouv.fr' }
    end

    factory :champ_phone, class: 'Champs::PhoneChamp' do
      type_de_champ { association :type_de_champ_phone, procedure: dossier.procedure }
      value { '0666666666' }
    end

    factory :champ_address, class: 'Champs::AddressChamp' do
      type_de_champ { association :type_de_champ_address, procedure: dossier.procedure }
      value { '2 rue des Démarches' }
    end

    factory :champ_yes_no, class: 'Champs::YesNoChamp' do
      type_de_champ { association :type_de_champ_yes_no, procedure: dossier.procedure }
      value { 'true' }
    end

    factory :champ_drop_down_list, class: 'Champs::DropDownListChamp' do
      type_de_champ { association :type_de_champ_drop_down_list, procedure: dossier.procedure }
      value { 'choix 1' }
    end

    factory :champ_multiple_drop_down_list, class: 'Champs::MultipleDropDownListChamp' do
      type_de_champ { association :type_de_champ_multiple_drop_down_list, procedure: dossier.procedure }
      value { '["choix 1", "choix 2"]' }
    end

    factory :champ_linked_drop_down_list, class: 'Champs::LinkedDropDownListChamp' do
      type_de_champ { association :type_de_champ_linked_drop_down_list, procedure: dossier.procedure }
      value { '["categorie 1", "choix 1"]' }
    end

    factory :champ_pays, class: 'Champs::PaysChamp' do
      type_de_champ { association :type_de_champ_pays, procedure: dossier.procedure }
      value { 'France' }
    end

    factory :champ_regions, class: 'Champs::RegionChamp' do
      type_de_champ { association :type_de_champ_regions, procedure: dossier.procedure }
      value { 'Guadeloupe' }
    end

    factory :champ_departements, class: 'Champs::DepartementChamp' do
      type_de_champ { association :type_de_champ_departements, procedure: dossier.procedure }
      value { '971 - Guadeloupe' }
    end

    factory :champ_communes, class: 'Champs::CommuneChamp' do
      type_de_champ { association :type_de_champ_communes, procedure: dossier.procedure }
      value { 'Paris' }
    end

    factory :champ_engagement, class: 'Champs::EngagementChamp' do
      type_de_champ { association :type_de_champ_engagement, procedure: dossier.procedure }
      value { 'true' }
    end

    factory :champ_header_section, class: 'Champs::HeaderSectionChamp' do
      type_de_champ { association :type_de_champ_header_section, procedure: dossier.procedure }
      value { 'une section' }
    end

    factory :champ_explication, class: 'Champs::ExplicationChamp' do
      type_de_champ { association :type_de_champ_explication, procedure: dossier.procedure }
      value { '' }
    end

    factory :champ_dossier_link, class: 'Champs::DossierLinkChamp' do
      type_de_champ { association :type_de_champ_dossier_link, procedure: dossier.procedure }
      value { create(:dossier).id }
    end

    factory :champ_piece_justificative, class: 'Champs::PieceJustificativeChamp' do
      type_de_champ { association :type_de_champ_piece_justificative, procedure: dossier.procedure }

      after(:build) do |champ, _evaluator|
        champ.piece_justificative_file.attach(io: StringIO.new("toto"), filename: "toto.txt", content_type: "text/plain")
      end
    end

    factory :champ_carte, class: 'Champs::CarteChamp' do
      type_de_champ { association :type_de_champ_carte, procedure: dossier.procedure }
    end

    factory :champ_siret, class: 'Champs::SiretChamp' do
      association :type_de_champ, factory: [:type_de_champ_siret]
      association :etablissement, factory: [:etablissement]
      value { '44011762001530' }
    end

    factory :champ_repetition, class: 'Champs::RepetitionChamp' do
      type_de_champ { association :type_de_champ_repetition, procedure: dossier.procedure }

      trait :with_rows do
        after(:build) do |champ_repetition, _evaluator|
          type_de_champ_text = build(:type_de_champ_text,
            order_place: 0,
            procedure: champ_repetition.dossier.procedure,
            parent: champ_repetition.type_de_champ,
            libelle: 'Nom'
          )
          type_de_champ_number = build(:type_de_champ_number,
            order_place: 1,
            procedure: champ_repetition.dossier.procedure,
            parent: champ_repetition.type_de_champ,
            libelle: 'Age'
          )

          champ_repetition.champs << [
            build(:champ_text, dossier: champ_repetition.dossier, row: 0, type_de_champ: type_de_champ_text, parent: champ_repetition),
            build(:champ_number, dossier: champ_repetition.dossier,row: 0, type_de_champ: type_de_champ_number, parent: champ_repetition),
            build(:champ_text, dossier: champ_repetition.dossier, row: 1, type_de_champ: type_de_champ_text, parent: champ_repetition),
            build(:champ_number, dossier: champ_repetition.dossier, row: 1, type_de_champ: type_de_champ_number, parent: champ_repetition)
          ]
        end
      end
    end

    factory :champ_repetition_with_piece_jointe, class: 'Champs::RepetitionChamp' do
      type_de_champ { association :type_de_champ_repetition, procedure: dossier.procedure }

      after(:build) do |champ_repetition, _evaluator|
        type_de_champ_pj0 = build(:type_de_champ_piece_justificative,
          procedure: champ_repetition.dossier.procedure,
          order_place: 0,
          parent: champ_repetition.type_de_champ,
          libelle: 'Justificatif de domicile'
        )
        type_de_champ_pj1 = build(:type_de_champ_piece_justificative,
          procedure: champ_repetition.dossier.procedure,
          order_place: 1,
          parent: champ_repetition.type_de_champ,
          libelle: 'Carte d\'identité'
        )

        champ_repetition.champs << [
          build(:champ_piece_justificative, dossier: champ_repetition.dossier, row: 0, type_de_champ: type_de_champ_pj0),
          build(:champ_piece_justificative, dossier: champ_repetition.dossier, row: 0, type_de_champ: type_de_champ_pj1),
          build(:champ_piece_justificative, dossier: champ_repetition.dossier, row: 1, type_de_champ: type_de_champ_pj0),
          build(:champ_piece_justificative, dossier: champ_repetition.dossier, row: 1, type_de_champ: type_de_champ_pj1)
        ]
      end
    end
  end
end
