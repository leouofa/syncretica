# frozen_string_literal: true

class AddParentReportToClusterReports < ActiveRecord::Migration[8.1]
  def change
    add_reference :cluster_reports, :parent_report,
                  null: true,
                  foreign_key: { to_table: :cluster_reports, on_delete: :nullify },
                  index: true
  end
end
