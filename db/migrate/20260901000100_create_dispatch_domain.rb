class CreateDispatchDomain < ActiveRecord::Migration[7.2]
  def change
    create_enum :courier_availability, %w[offline available reserved carrying]

    create_table :hubs, id: :uuid do |t|
      t.string :name, null: false
      t.st_point :location, geographic: true, srid: 4326, null: false
      t.st_polygon :delivery_zone, geographic: true, srid: 4326, null: false
      t.timestamps
    end
    add_index :hubs, :location, using: :gist
    add_index :hubs, :delivery_zone, using: :gist

    create_table :couriers, id: :uuid do |t|
      t.string :name, null: false
      t.enum :availability, enum_type: :courier_availability, null: false, default: "offline"
      t.st_point :location, geographic: true, srid: 4326
      t.datetime :location_observed_at
      t.timestamps
    end
    add_index :couriers, :location, using: :gist

    create_table :deliveries, id: :uuid do |t|
      t.uuid :hub_id, null: false
      t.uuid :courier_id
      t.string :external_id, null: false
      t.st_point :pickup, geographic: true, srid: 4326, null: false
      t.st_point :dropoff, geographic: true, srid: 4326, null: false
      t.string :recipient_name, null: false
      t.string :recipient_phone, null: false
      t.integer :eta_seconds
      t.datetime :picked_up_at
      t.datetime :delivered_at
      t.datetime :cancelled_at
      t.datetime :proof_stored_at
      t.timestamps
    end
    add_foreign_key :deliveries, :hubs
    add_foreign_key :deliveries, :couriers
    add_index :deliveries, :external_id, unique: true
    add_index :deliveries, :pickup, using: :gist
    add_index :deliveries, :dropoff, using: :gist

    create_table :delivery_transitions, id: :uuid do |t|
      t.uuid :delivery_id, null: false
      t.string :to_state, null: false
      t.jsonb :metadata, null: false, default: {}
      t.integer :sort_key, null: false
      t.boolean :most_recent, null: false, default: false
      t.timestamps
    end
    add_foreign_key :delivery_transitions, :deliveries
    add_index :delivery_transitions, %i[delivery_id sort_key], unique: true
    add_index :delivery_transitions, :delivery_id, unique: true, where: "most_recent"

    create_table :dispatch_attempts, id: :uuid do |t|
      t.uuid :delivery_id, null: false
      t.uuid :courier_id
      t.string :outcome, null: false
      t.string :reason
      t.integer :duration_ms, null: false
      t.timestamps
    end
    add_foreign_key :dispatch_attempts, :deliveries
    add_foreign_key :dispatch_attempts, :couriers
    add_index :dispatch_attempts, :delivery_id

    create_table :outbox_events, id: :uuid do |t|
      t.string :event_type, null: false
      t.uuid :aggregate_id, null: false
      t.jsonb :payload, null: false, default: {}
      t.datetime :dispatched_at
      t.timestamps
    end
    add_index :outbox_events, :dispatched_at, where: "dispatched_at IS NULL"

    create_table :http_idempotency_records, id: :uuid do |t|
      t.string :subject, null: false
      t.string :key, null: false
      t.string :request_hash, null: false
      t.integer :response_status
      t.jsonb :response_body
      t.datetime :expires_at, null: false
      t.timestamps
    end
    add_index :http_idempotency_records, %i[subject key], unique: true
    add_index :http_idempotency_records, :expires_at
  end
end
