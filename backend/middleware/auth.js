const verifyToken = require('../utils/verifyToken');

// ใช้ middleware นี้กับ route ที่ต้องการให้ login ก่อนถึงจะเข้าถึงได้
const authMiddleware = async (req, res, next) => {
  const authHeader = req.headers.authorization; // รูปแบบ: "Bearer <token>"

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ message: 'No token provided. Please sign in' });
  }

  const token = authHeader.split(' ')[1];

  try {
    req.userId = await verifyToken(token);
  } catch (err) {
    if (!err.auth) {
      console.error(err);
      return res.status(500).json({ message: 'Server error' });
    }
    return res.status(401).json({ message: 'Invalid or expired token' });
  }
  next();
};

module.exports = authMiddleware;
