
require('dotenv').config();

const express = require('express');
const cors = require('cors');
const connectDatabase = require('./config/database');
const authRoutes = require('./routes/auth');
const taskRoutes = require('./routes/tasks');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
  res.json({
    message: 'Task Manager API dang hoat dong!'
  });
});

app.get('/api/health', (req, res) => {
  res.json({
    success: true,
    message: 'Backend va MongoDB dang hoat dong'
  });
});

app.use('/api/auth', authRoutes);
app.use('/api/tasks', taskRoutes);

async function startServer() {
  try {
    await connectDatabase();

    app.listen(PORT, () => {
      console.log(`Server dang chay tai http://localhost:${PORT}`);
    });
  } catch (error) {
    console.error('Khong the khoi dong server:', error.message);
    process.exit(1);
  }
}

startServer();
