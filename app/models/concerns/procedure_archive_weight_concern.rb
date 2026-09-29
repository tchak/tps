# frozen_string_literal: true

# Predicts the weight of a monthly archive before it is generated: the archives
# pages multiply the number of terminated dossiers of the month by the average
# weight of a dossier in an archive. The zip stores files uncompressed, so the
# sum of the blob sizes is a faithful prediction.
module ProcedureArchiveWeightConcern
  extend ActiveSupport::Concern

  # Size of the export-<id>.pdf that opens every dossier folder, measured on the
  # 84 k dossier PDFs stored in production (2026-09): p50 104 kB, p90 129 kB.
  DOSSIER_PDF_WEIGHT = 110.kilobytes

  # Enough dossiers for a stable mean, few enough to keep the queries cheap.
  ARCHIVE_WEIGHT_SAMPLE_SIZE = 100

  # The estimate is a slow-moving figure and its queries walk the attachments of
  # a hundred dossiers: one computation a day per procedure is plenty. When the
  # entry expires, one request recomputes it while the others keep the stale
  # value for a while, instead of every request recomputing at once.
  ARCHIVE_WEIGHT_CACHE_DURATION = 1.day
  ARCHIVE_WEIGHT_CACHE_GRACE = 1.minute

  # Cached in place of the weight when the procedure has no archivable dossier.
  # It is the case where the sample query walks the most rows for nothing (many
  # dossiers, none terminated), so it is the last one to recompute on every
  # page view; the archives page has no month to estimate then anyway.
  NO_ARCHIVABLE_DOSSIER = :none

  def average_dossier_weight
    weight = Rails.cache.fetch(['procedure', id, 'average_dossier_weight'], expires_in: ARCHIVE_WEIGHT_CACHE_DURATION, race_condition_ttl: ARCHIVE_WEIGHT_CACHE_GRACE) do
      compute_average_dossier_weight || NO_ARCHIVABLE_DOSSIER
    end

    weight unless weight == NO_ARCHIVABLE_DOSSIER
  end

  private

  def compute_average_dossier_weight
    # Any hundred archivable dossiers: an order would sort the whole population
    # of the procedure (no index carries processed_at, and the ones on
    # groupe_instructeur_id only order within one groupe), where the unordered
    # walk of the revision_id index stops at the hundredth row.
    dossier_ids = dossiers.archivable.limit(ARCHIVE_WEIGHT_SAMPLE_SIZE).ids
    return if dossier_ids.empty?

    total_size = archive_attachment_sources(dossier_ids).sum do |record_type, names, record_ids|
      archive_attachments_size(record_type, names, record_ids)
    end

    DOSSIER_PDF_WEIGHT + total_size / dossier_ids.size
  end

  # The attachments PiecesJustificativesService puts in an archive, by owner.
  # The archive skips titres d'identité: they are another champ type, so the
  # type filter leaves them out. It ships the current value of every champ: the
  # history streams keep their own copies of the pièces jointes they replaced.
  def archive_attachment_sources(dossier_ids)
    pj_champs = ChampData.where(type: Champs::PieceJustificativeChamp.to_s, stream: Dossier::MAIN_STREAM, dossier_id: dossier_ids)

    [
      ['Champ', 'piece_justificative_file', pj_champs.select(:id)],
      ['Commentaire', 'piece_jointe', Commentaire.where(dossier_id: dossier_ids).select(:id)],
      ['Dossier', 'justificatif_motivation', dossier_ids],
      ['Attestation', 'pdf', Attestation.where(dossier_id: dossier_ids).select(:id)],
      ['Avis', ['introduction_file', 'piece_justificative_file'], Avis.where(dossier_id: dossier_ids).select(:id)],
      ['Etablissement', ['entreprise_attestation_sociale', 'entreprise_attestation_fiscale'], Etablissement.where(dossier_id: dossier_ids).select(:id)],
    ]
  end

  # One query per owner keeps every plan a semi join on the attachments
  # uniqueness index; a single OR over the sources tempts the planner into a
  # scan of the whole table.
  def archive_attachments_size(record_type, names, record_ids)
    ActiveStorage::Attachment
      .joins(:blob)
      .where(record_type:, name: names, record_id: record_ids)
      # what the archive skips too: purged blobs, and blobs not (yet) scanned safe
      .where(active_storage_blobs: { soft_deleted_at: nil, virus_scan_result: ActiveStorage::VirusScanner::SAFE })
      .sum('active_storage_blobs.byte_size')
  end
end
