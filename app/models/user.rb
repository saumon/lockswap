class User < ApplicationRecord
  # :database_authenticatable — bcrypt password storage + email/password login (FR-004, FR-006)
  # :registerable            — self-service signup (FR-001, FR-003)
  # :rememberable            — persistent session across browser restarts, 30 days (FR-007)
  # :lockable                — lock after 5 consecutive failures for 15 minutes (FR-011)
  # :validatable             — email format/uniqueness and the 8-character password minimum (FR-002)
  devise :database_authenticatable, :registerable,
         :rememberable, :lockable, :validatable
end
