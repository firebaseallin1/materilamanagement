# Material Catalog Feature - Implementation Guide

## Overview

A complete Material Catalog management system has been integrated into your Flutter Material Management app. This feature allows users to view, create, edit, and delete materials with an intuitive UI.

## Files Created

### 1. **Material Model** (`lib/models/material_model.dart`)

Defines the Material data structure with the following properties:

- `id` - Unique identifier
- `name` - Material name
- `category` - Material category (Cement, Steel, Sand, etc.)
- `unit` - Unit of measurement (kg, liters, pieces, bags, etc.)
- `quantity` - Available quantity
- `price` - Unit price
- `description` - Detailed description
- `imageUrl` - Optional image URL
- `isActive` - Active/Inactive status
- `createdAt` - Creation timestamp

### 2. **Material Provider** (`lib/providers/material_provider.dart`)

State management using Provider pattern with:

- **Sample Data**: Pre-populated with 5 sample materials
- **Categories**: Cement, Steel, Sand, Aggregate, Brick, Paint, Electrical, Plumbing, Wood, Tiles
- **Units**: kg, liters, pieces, bags, sheets, meters, square meters, cubic meters
- **CRUD Operations**:
  - `createMaterial()` - Add new material
  - `updateMaterial()` - Update existing material
  - `deleteMaterial()` - Delete material
- **Features**:
  - Automatic ID generation
  - Mock API delays (500ms) for realistic UX
  - Error handling and notifications

### 3. **Web UI** (`lib/screens/web/material_catalog_web.dart`)

Professional web interface featuring:

#### Header Section

- Page title: "Material Catalog"
- "Add New Material" button (blue, Material Design 3)

#### Search & Filter

- Search by material name
- Category filter dropdown (All + 10 categories)
- Real-time filtering

#### Material List Table

| Column        | Details                    |
| ------------- | -------------------------- |
| Material Name | Name + Description         |
| Category      | Color-coded badge          |
| Quantity      | Numeric value              |
| Unit Price    | Green text with ₹ symbol   |
| Status        | Active/Inactive badge      |
| Actions       | View, Edit, Delete buttons |

#### Features

- Empty state with icon
- Responsive table layout
- Hover effects on table rows
- Toast notifications for actions
- Material details dialog
- Create/Edit dialogs with validation

### 4. **Mobile UI** (`lib/screens/mobile/material_catalog_mobile.dart`)

Mobile-optimized interface featuring:

#### AppBar

- Title: "Material Catalog"
- Dark blue background

#### Floating Action Button

- "Add Material" button for easy access

#### Material Cards

- Material name (large, bold)
- Description (2 lines max)
- Category badge
- Quantity display
- Unit price (large, green)
- Status badge
- Action buttons (View, Edit, Delete)

#### Features

- Search bar
- Category filter dropdown
- Card-based layout
- Bottom sheet support
- Mobile-friendly dialogs

### 5. **Responsive Wrapper** (`lib/responsive/material_catalog_responsive.dart`)

Automatically selects between web and mobile UI based on screen width (>800px = Web).

## Navigation Integration

The Material Catalog is accessible via:

1. **Sidebar Menu** → Masters → Material → Material Catalog
2. Automatically handled by DashboardProvider

### Updated Files

- `lib/main.dart` - Added MaterialProvider to MultiProvider
- `lib/providers/dashboard_provider.dart` - Added navigation logic for Material Catalog

## Usage Instructions

### Accessing Material Catalog

1. Login to the application
2. Go to sidebar → Masters → Material
3. Click on "Material Catalog"

### Adding a New Material

1. Click "Add New Material" button
2. Fill in the form:
   - Material Name (required)
   - Category (dropdown)
   - Quantity (required)
   - Unit (dropdown)
   - Unit Price (required)
   - Description
3. Click "Add Material"

### Viewing Material Details

- Click the **View** button on any material card/row
- A dialog displays all material information including total value calculation

### Editing Material

- Click the **Edit** button on any material
- Modify the required fields
- Check/uncheck "Active" status
- Click "Update Material"

### Deleting Material

- Click the **Delete** button
- Confirm deletion in the confirmation dialog

### Searching Materials

- Use the search bar to find materials by name
- Results update in real-time

### Filtering by Category

- Use the category dropdown
- Select "All" to see all materials
- Filter updates instantly

## UI Features & Colors

### Color Scheme

- **Primary**: `#173D6D` (Dark Blue)
- **Background**: `#EFF6FB` (Light Blue)
- **Success**: `#059669` (Green)
- **Danger**: `#DC2626` (Red)
- **Text**: `#111827` (Dark Gray)
- **Border**: `#e5e7eb` (Light Gray)

### Components

- **Buttons**: Rounded (12-14px border radius)
- **Cards**: White with subtle shadows
- **Tables**: Bordered rows with hover effects
- **Badges**: Rounded pills with background colors
- **Icons**: Material Icons throughout

## Data Management

### Sample Materials

The app comes with 5 pre-loaded materials:

1. Portland Cement - 150 bags @ ₹350/bag
2. Mild Steel Rod - 500 kg @ ₹45/kg
3. Construction Sand - 200 m³ @ ₹500/m³
4. Coarse Aggregate - 150 m³ @ ₹600/m³
5. Red Bricks - 5000 pieces @ ₹5.50/piece

### Adding to Database

Currently using in-memory storage. To integrate with MongoDB:

1. Update MaterialProvider with API calls
2. Replace sample data initialization with MongoDB queries
3. Use your existing `api_service.dart` for backend communication

## Customization Guide

### Adding More Categories

Edit `lib/providers/material_provider.dart`:

```dart
static const List<String> categories = [
  'Cement',
  'Steel',
  'Sand',
  'Aggregate',
  'Brick',
  'Paint',
  'Electrical',
  'Plumbing',
  'Wood',
  'Tiles',
  'Glass',  // Add new category
];
```

### Changing Colors

Edit color codes in `material_catalog_web.dart` and `material_catalog_mobile.dart`:

- `Color(0xFF173D6D)` - Primary blue
- `Color(0xFF059669)` - Success green
- `Color(0xFFDC2626)` - Danger red

### Modifying Table Columns

In `_MaterialTableRow` widget (web version):

- Adjust `Expanded(flex: X)` to resize columns
- Add/remove Column renders

### Adding Image Support

1. Add image upload in create/edit dialogs
2. Update Material model to store image paths
3. Display images in cards/table rows

## API Integration Notes

### For Backend Integration

1. **Create Material** - POST `/api/materials`
2. **Get Materials** - GET `/api/materials`
3. **Update Material** - PUT `/api/materials/:id`
4. **Delete Material** - DELETE `/api/materials/:id`

Use your existing `api_service.dart` to make these requests instead of in-memory operations.

## Error Handling

- Input validation on forms
- Try-catch blocks for async operations
- User-friendly error messages via SnackBar
- Confirmation dialogs for destructive actions

## Best Practices Implemented

✅ Material Design 3 principles
✅ Responsive design (Web & Mobile)
✅ Provider pattern for state management
✅ Form validation
✅ Error handling
✅ Loading states
✅ Empty state handling
✅ Toast notifications
✅ Confirmation dialogs
✅ Accessibility with icons and tooltips

## Performance Considerations

- Efficient list rendering with ListView.separated
- Filtered list to reduce item count
- Mock delays (500ms) simulate network latency
- Platform-specific UI for better performance

---

**Status**: ✅ Ready to Use  
**Last Updated**: 2026-04-16  
**Version**: 1.0.0
