class ScreenDef {
  final String key;
  final String label;
  final String section;
  const ScreenDef(this.key, this.label, this.section);
}

const kAllScreens = [
  ScreenDef('attendance',  'Attendance',        'Operations'),
  ScreenDef('advances',    'Advances',          'Operations'),
  ScreenDef('outstanding', 'Outstanding',       'Operations'),
  ScreenDef('stock',       'Material Stock',    'Operations'),
  ScreenDef('transport',   'Transport Detail',  'Operations'),
  ScreenDef('expenses',    'Expenses',          'Operations'),
  ScreenDef('payments',    'Payments',          'Operations'),
  ScreenDef('branches',    'Branches',          'Masters'),
  ScreenDef('location',    'Location',          'Masters'),
  ScreenDef('category',    'Category',          'Masters'),
  ScreenDef('expense_cat', 'Expense Category',  'Masters'),
  ScreenDef('user_cat',    'User Category',     'Masters'),
  ScreenDef('materials',   'Material',          'Masters'),
  ScreenDef('employees',   'Employees',         'Masters'),
  ScreenDef('users',       'Users',             'Admin'),
  ScreenDef('reports',      'Mesr vs Payments',  'Reports'),
  ScreenDef('profit_loss',    'Profit & Loss',   'Reports'),
  ScreenDef('account_report',    'Account Report',    'Reports'),
  ScreenDef('expense_report',    'Expense Report',    'Reports'),
  ScreenDef('attendance_report', 'Attendance Report', 'Reports'),
];
