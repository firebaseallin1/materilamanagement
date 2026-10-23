# Using MongoDB Playground in VS Code

## Pre-requisites

- MongoDB for VS Code extension installed
- Connected to MongoDB (local or Atlas)
- VS Code open

## How to Use MongoDB Playground

### Step 1: Create a New Playground File

1. Open VS Code Command Palette: `Ctrl+Shift+P` (Windows/Linux) or `Cmd+Shift+P` (Mac)
2. Type: `MongoDB: Create MongoDB Playground`
3. Choose database: `material_management`
4. File will open as `playground1.mongodb.js`

### Step 2: Copy Setup Script

1. Open the file: `backend/mongodb_playground_setup.js` in your project
2. Copy the entire content
3. Paste into your MongoDB Playground file in VS Code

### Step 3: Run the Script

**Option A: Run Entire Script**

- Click **"Run All"** button at top of editor (or use keyboard shortcut)
- Or right-click and select "Run All"

**Option B: Run Selected Lines**

- Select lines you want to run
- Right-click → "Run Selection"

**Option C: Run Line by Line**

- Click the "Run" icon that appears on the left of each line

### Step 4: View Results

Results will appear in a panel at the bottom showing:

- Documents inserted
- Documents found
- Query results
- Count of records

---

## Quick Commands to Test

### Test Connection

```javascript
use("material_management");
db.users.countDocuments();
```

### Find Admin User

```javascript
use("material_management");
db.users.findOne({ role: "admin" });
```

### Find All Users

```javascript
use("material_management");
db.users.find().pretty();
```

### Find Mobile Users Only

```javascript
use("material_management");
db.users.find({ role: "mobile_user" });
```

### Find Web Users Only

```javascript
use("material_management");
db.users.find({ role: "web_user" });
```

### Update a User

```javascript
use("material_management");
db.users.updateOne(
  { email: "admin@example.com" },
  { $set: { name: "Updated Admin Name" } },
);
```

### Delete a User

```javascript
use("material_management");
db.users.deleteOne({ email: "mobile.user1@example.com" });
```

### Count by Role

```javascript
use("material_management");
db.users.aggregate([{ $group: { _id: "$role", count: { $sum: 1 } } }]);
```

---

## Test Data Available

After running the setup script, you have:

### Admin User

```
Email: admin@example.com
Password: adminpass123
Role: admin
```

### Mobile Users (3)

```
mobile.user1@example.com / password123
mobile.user2@example.com / password123
mobile.user3@example.com / password123
```

### Web Users (2)

```
web.user1@example.com / password123
web.user2@example.com / password123
```

---

## Common Issues & Solutions

### "Connection Refused Error"

- MongoDB server not running
- Solution: Start MongoDB service

### "Database Not Found"

- Database doesn't exist yet (MongoDB creates on first write)
- Run the setup script to create it

### "Status: Pending"

- Still connecting to MongoDB
- Wait a few seconds and try again

### "Cannot Connect to Cluster"

- Check connection string in VS Code MongoDB extension settings
- Verify MongoDB is running

---

## Playground Features

### Insert Data

```javascript
db.collection.insertOne({
  /* document */
});
db.collection.insertMany([
  /* documents */
]);
```

### Query Data

```javascript
db.collection.find({ condition });
db.collection.findOne({ condition });
db.collection.find().pretty(); // Pretty print
```

### Update Data

```javascript
db.collection.updateOne({ query }, { $set: { field: value } });
db.collection.updateMany({ query }, { $set: { field: value } });
```

### Delete Data

```javascript
db.collection.deleteOne({ query });
db.collection.deleteMany({ query });
```

### Aggregation Pipeline

```javascript
db.collection.aggregate([
  { $match: { condition } },
  { $group: { _id: "$field", count: { $sum: 1 } } },
  { $sort: { count: -1 } },
]);
```

---

## Tips & Tricks

1. **Use `.pretty()`** for better formatting of results
2. **Use `Ctrl+/`** to comment/uncomment lines
3. **Use auto-complete** by pressing `Ctrl+Space`
4. **Save playgrounds** with meaningful names
5. **Create multiple playgrounds** for different tasks
6. **Check output panel** for detailed results

---

## Next Steps After Setup

1. ✅ Run the setup script to create users
2. ✅ Test login in Flutter app with admin credentials
3. ✅ Test creating new users via API
4. ✅ Verify mobile and web user logins
5. → Add more data models (materials, inventory, etc.)
6. → Create aggregation queries for reports

---

## MongoDB Playground Keyboard Shortcuts

| Action          | Windows/Linux    | Mac                |
| --------------- | ---------------- | ------------------ |
| Run All         | `Ctrl+Alt+Enter` | `Cmd+Option+Enter` |
| Run Selection   | `Ctrl+Enter`     | `Cmd+Enter`        |
| Format Document | `Shift+Alt+F`    | `Shift+Option+F`   |
| Find            | `Ctrl+F`         | `Cmd+F`            |
| Comment Line    | `Ctrl+/`         | `Cmd+/`            |

---

For more details: [MongoDB for VS Code Documentation](https://www.mongodb.com/docs/mongodb-vscode/)
