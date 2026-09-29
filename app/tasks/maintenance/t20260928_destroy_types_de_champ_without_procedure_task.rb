# frozen_string_literal: true

module Maintenance
  class T20260928DestroyTypesDeChampWithoutProcedureTask < MaintenanceTasks::Task
    # Documentation: cette tâche supprime les types de champ rattachés à aucune
    # démarche (`types_de_champ.procedure_id`) : ceux qu’aucune révision ne
    # dispose plus, laissés derrière par les anciennes suppressions et les
    # clonages, avant que la publication ne les purge. Un type de champ encore
    # disposé par une révision est laissé de côté : c’est à
    # T20260918BackfillTypeDeChampProcedureIdTask de le rattacher.

    # Deliberately manual: a quarter of the types de champ, walked by primary
    # key. It must not fire on a deploy.
    def collection
      TypeDeChamp.where(procedure_id: nil).where.missing(:revision_type_de_champs).in_batches
    end

    def process(batch)
      ids = batch.pluck(:id)
      attached_ids = ActiveStorage::Attachment.where(record_type: 'TypeDeChamp', record_id: ids).distinct.pluck(:record_id)

      # destroyed: the template or the notice attached go with them
      TypeDeChamp.where(id: attached_ids).find_each(&:destroy)
      # nothing refers to the others (the champs hold the stable id): deleted outright
      TypeDeChamp.where(id: ids - attached_ids).delete_all
    end
  end
end
