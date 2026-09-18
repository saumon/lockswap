class CreateAllowedEmailDomains < ActiveRecord::Migration[8.1]
  def change
    # 016 FR-003: one row per allowed domain rather than a delimited list on a
    # settings row. Adding and removing a domain are then an INSERT and a DELETE,
    # and the two rules the spec's Edge Cases ask for — reject a malformed entry,
    # refuse a duplicate — are a format validation and a unique index rather than
    # parsing code run on every save (research.md R1).
    create_table :allowed_email_domains do |t|
      t.string :domain, null: false

      t.timestamps
    end

    # FR-003, Edge Cases: no functional duplicates. Plain unique rather than a
    # case-insensitive expression index because the model normalizes the column
    # to lowercase before it is ever written, so "Company.com" and "company.com"
    # arrive here as the same string (data-model.md "Normalization").
    add_index :allowed_email_domains, :domain, unique: true
  end
end
