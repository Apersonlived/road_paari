import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../data/models/poi_model.dart';
import '../../../providers/poi_provider.dart';
import '../../../providers/auth_provider.dart';
import '../../widgets/poi_card.dart';

class AdminPOIScreen extends StatefulWidget {
  const AdminPOIScreen({super.key});

  @override
  State<AdminPOIScreen> createState() => _AdminPOIScreenState();
}

class _AdminPOIScreenState extends State<AdminPOIScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<POIProvider>().loadPOIs();
      context.read<POIProvider>().loadCategories();
    });
  }

  void _confirmDelete(BuildContext context, POI poi) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete POI'),
        content: Text('Are you sure you want to delete "${poi.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await context.read<POIProvider>().deletePOI(poi.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(success
                        ? '${poi.name} deleted'
                        : context.read<POIProvider>().error ?? 'Delete failed'),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showPOIForm(BuildContext context, {POI? poi}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => POIFormSheet(poi: poi),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();

    if (auth.currentUser == null || auth.currentUser!.isAdmin != true) {
      return const Scaffold(
        body: Center(child: Text('Access denied — admins only')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage POIs'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPOIForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add POI'),
      ),
      body: Consumer<POIProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.pois.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.error != null && provider.pois.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.loadPOIs(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.pois.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off, size: 48, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No POIs yet. Add one!',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadPOIs(refresh: true),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: provider.pois.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12), // ← fix
              itemBuilder: (context, index) {
                final poi = provider.pois[index];
                return POICard(
                  poi: poi,
                  showActions: true,
                  onEdit: () => _showPOIForm(context, poi: poi),
                  onDelete: () => _confirmDelete(context, poi),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

// POI Form Bottom Sheet
class POIFormSheet extends StatefulWidget {
  final POI? poi;
  const POIFormSheet({super.key, this.poi});

  @override
  State<POIFormSheet> createState() => _POIFormSheetState();
}

class _POIFormSheetState extends State<POIFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _latController;
  late final TextEditingController _lngController;

  int? _selectedCategoryId;
  File? _pickedImage; // local file selected by the user for upload
  bool _removeExistingImage = false;
  final _picker = ImagePicker();

  bool get _isEditing => widget.poi != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.poi?.name ?? '');
    _descController =
        TextEditingController(text: widget.poi?.description ?? '');
    _latController =
        TextEditingController(text: widget.poi?.latitude?.toString() ?? '');
    _lngController =
        TextEditingController(text: widget.poi?.longitude?.toString() ?? '');
    _selectedCategoryId = widget.poi?.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  // Image picker 
  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() {
        _pickedImage = File(picked.path);
        _removeExistingImage = false; // picking a new one overrides removal
      });
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_pickedImage != null ||
                (widget.poi?.imageUrl != null && !_removeExistingImage))
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Remove image',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _pickedImage = null;
                    _removeExistingImage = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  // Submit 
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<POIProvider>();
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());

    bool success;
    int? poiId;

    if (_isEditing) {
      success = await provider.updatePOI(
        poiId: widget.poi!.id,
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        categoryId: _selectedCategoryId,
        latitude: lat,
        longitude: lng,
      );
      poiId = widget.poi!.id;
    } else {
      success = await provider.createPOI(
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        categoryId: _selectedCategoryId,
        latitude: lat!,
        longitude: lng!,
      );
      // Get the newly created POI id from the top of the list
      if (success) poiId = provider.pois.first.id;
    }

    if (!success || poiId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Something went wrong'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Handle image upload / removal
    if (_pickedImage != null) {
      // Upload new image
      await provider.uploadPOIImage(poiId, _pickedImage!.path);
    } else if (_removeExistingImage && _isEditing) {
      // Delete existing image via PATCH with null image_url
      await provider.updatePOI(poiId: poiId, imageUrl: null);
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'POI updated' : 'POI created'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Build
  Widget _buildImagePicker() {
    final existingUrl = widget.poi?.imageUrl;
    final hasExisting = existingUrl != null && !_removeExistingImage;

    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        clipBehavior: Clip.hardEdge,
        child: _pickedImage != null
            ? Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(_pickedImage!, fit: BoxFit.cover),
                  _imageOverlay(),
                ],
              )
            : hasExisting
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(existingUrl, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _emptyImagePlaceholder()),
                      _imageOverlay(),
                    ],
                  )
                : _emptyImagePlaceholder(),
      ),
    );
  }

  Widget _emptyImagePlaceholder() => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 40, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text('Tap to add image',
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
        ],
      );

  Widget _imageOverlay() => Positioned(
        bottom: 8,
        right: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.edit, size: 14, color: Colors.white),
              SizedBox(width: 4),
              Text('Change', style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<POIProvider>().categories;
    final isLoading = context.watch<POIProvider>().isLoading;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 24, 24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                _isEditing ? 'Edit POI' : 'Add New POI',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // Image picker
              _buildImagePicker(),
              const SizedBox(height: 16),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),

              // Description
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),

              // Category dropdown
              DropdownButtonFormField<int>(
                initialValue: _selectedCategoryId, 
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('None')),
                  ...categories.map(
                    (cat) => DropdownMenuItem(
                      value: cat.id,
                      child: Text(cat.name),
                    ),
                  ),
                ],
                onChanged: (val) => setState(() => _selectedCategoryId = val),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return _isEditing ? null : 'Required';
                        }
                        final d = double.tryParse(v.trim());
                        if (d == null || d < -90 || d > 90) {
                          return 'Invalid latitude';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true, signed: true),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return _isEditing ? null : 'Required';
                        }
                        final d = double.tryParse(v.trim());
                        if (d == null || d < -180 || d > 180) {
                          return 'Invalid longitude';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          _isEditing ? 'Save Changes' : 'Create POI',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}