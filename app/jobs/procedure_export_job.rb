class ProcedureExportJob < ApplicationJob
  def perform(procedure, format)
    procedure.prepare_export_download(format)
  end
end
