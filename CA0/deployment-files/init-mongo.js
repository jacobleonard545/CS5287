// MongoDB initialization script
// Creates database and collections for the pipeline

db = db.getSiblingDB('sensordata');

// Create collections
db.createCollection('raw_sensor_data');
db.createCollection('processed_data');

// Create indexes for better performance
db.raw_sensor_data.createIndex({ "timestamp": 1 });
db.raw_sensor_data.createIndex({ "sensor_id": 1 });
db.raw_sensor_data.createIndex({ "timestamp": 1, "sensor_id": 1 });

db.processed_data.createIndex({ "processed_timestamp": 1 });
db.processed_data.createIndex({ "sensor_id": 1 });
db.processed_data.createIndex({ "alert_level": 1 });

// Create a user for the application
db.createUser({
  user: "pipeline_user",
  pwd: "pipeline_pass_2023",
  roles: [
    {
      role: "readWrite",
      db: "sensordata"
    }
  ]
});

// Insert sample document to verify setup
db.raw_sensor_data.insertOne({
  sensor_id: "INIT_SENSOR",
  timestamp: new Date(),
  temperature: 23.5,
  humidity: 65.2,
  status: "initialization_complete"
});

print("Database initialization completed successfully!");