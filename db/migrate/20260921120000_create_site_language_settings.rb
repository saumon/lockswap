class CreateSiteLanguageSettings < ActiveRecord::Migration[8.1]
  def change
    # 025 FR-004: one row, ever — the site-wide language, not a per-user column.
    # The model's .current (first_or_create!) and only_one_row_may_exist guard
    # enforce the singleton; the column default matches DEFAULT_LANGUAGE so the
    # row is correct even if a row were ever inserted outside .current.
    create_table :site_language_settings do |t|
      t.string :language, null: false, default: "en"

      t.timestamps
    end
  end
end
