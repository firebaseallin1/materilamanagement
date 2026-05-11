const { Attendance } = require('../models/Transactions');

exports.getAll = async (req, res) => {
  try {
    const { branch, employee, status, from, to, page = 1, limit = 50 } = req.query;
    const query = {};
    if (branch) query.branch = branch;
    if (employee) query.employee = employee;
    if (status) query.status = status;
    if (from || to) {
      query.date = {};
      if (from) query.date.$gte = new Date(from);
      if (to) query.date.$lte = new Date(to);
    }
    const skip = (page - 1) * limit;
    const [data, total] = await Promise.all([
      Attendance.find(query)
        .populate('employee', 'name photo')
        .populate('branch', 'name')
        .sort({ date: -1 }).skip(skip).limit(Number(limit)),
      Attendance.countDocuments(query),
    ]);
    res.json({ success: true, data, total });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.getOne = async (req, res) => {
  try {
    const doc = await Attendance.findById(req.params.id).populate('employee branch createdBy');
    if (!doc) return res.status(404).json({ success: false, message: 'Not found' });
    res.json({ success: true, data: doc });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.create = async (req, res) => {
  try {
    const { employee, date } = req.body;
    if (employee && date) {
      const dayStart = new Date(date);
      dayStart.setHours(0, 0, 0, 0);
      const dayEnd = new Date(date);
      dayEnd.setHours(23, 59, 59, 999);
      const exists = await Attendance.findOne({ employee, date: { $gte: dayStart, $lte: dayEnd } });
      if (exists) return res.status(400).json({ success: false, message: 'Attendance already marked for this employee on the selected date.' });
    }
    const doc = await Attendance.create({ ...req.body, createdBy: req.user.id });
    await doc.populate([{ path: 'employee', select: 'name photo' }, { path: 'branch', select: 'name' }]);
    res.status(201).json({ success: true, data: doc });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

exports.update = async (req, res) => {
  try {
    const doc = await Attendance.findByIdAndUpdate(req.params.id, req.body, { new: true })
      .populate('employee', 'name photo')
      .populate('branch', 'name');
    if (!doc) return res.status(404).json({ success: false, message: 'Not found' });
    res.json({ success: true, data: doc });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

exports.remove = async (req, res) => {
  try {
    await Attendance.findByIdAndDelete(req.params.id);
    res.json({ success: true, message: 'Deleted' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
