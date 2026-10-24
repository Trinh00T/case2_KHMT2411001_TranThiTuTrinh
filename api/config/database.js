
const mongoose = require('mongoose');

async function connectDatabase() {
  try {
    await mongoose.connect(process.env.MONGODB_URI);
    console.log('MongoDB ket noi thanh cong!');
  } catch (error) {
    console.error('Loi ket noi MongoDB:', error.message);
    process.exit(1);
  }
}

module.exports = connectDatabase;
