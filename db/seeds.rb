# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

# 031: a populated Danger Zone and Locker Map for local development, so the
# app looks like a real, in-use site instead of the "nothing configured yet"
# baseline every test deliberately starts from (site_floor_list_test.rb and
# friends). Development-only on purpose — production's floors, format and
# zones are the real building's, set by hand from the Danger Zone and the
# Locker Map, not from this file.
#
# Idempotent throughout: .current + update!/find_or_create_by! everywhere, so
# this can be re-run (bin/rails db:seed) at any point without duplicating or
# erroring on rows it already created.
if Rails.env.development?
  SiteLanguageSetting.current.update!(language: "fr")

  SiteFloorList.current.update!(floors_text: "RdC, 1, 2, 3, 4, 5")

  # Matches the zone ranges below: 001-040, 041-080, 081-120 are all exactly
  # three digits.
  LockerNumberFormat.current.update!(pattern: "\\d{3}", description: "3 chiffres, ex. 042.")

  # Three zones per floor, each with its forty lockers, zero-padded to match
  # the format above.
  zone_specs = [
    { name: "Casiers 001 à 040", numbers: 1..40 },
    { name: "Casiers 041 à 080", numbers: 41..80 },
    { name: "Casiers 081 à 120", numbers: 81..120 }
  ]

  ActiveRecord::Base.transaction do
    SiteFloorList.current.floors.each do |floor|
      zone_specs.each do |zone_spec|
        zone = Zone.find_or_create_by!(floor: floor, name: zone_spec[:name])

        zone_spec[:numbers].each do |number|
          zone.locker_map_entries.find_or_create_by!(locker_number: format("%03d", number))
        end
      end
    end
  end
end
