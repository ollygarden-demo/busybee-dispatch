class EnableExtensions < ActiveRecord::Migration[7.2]
  def change
    enable_extension "pgcrypto"
    enable_extension "postgis"
  end
end
