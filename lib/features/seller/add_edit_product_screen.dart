import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

import '../../repositories/product_repository.dart';
import '../../models/product_model.dart';
import '../../core/storage/product_storage_service.dart';
import '../../repositories/user_repository.dart';
import '../../config/categories.dart';

class AddEditProductScreen extends StatefulWidget {
  final String shopId;
  final ProductModel? product;

  const AddEditProductScreen({
    super.key,
    required this.shopId,
    this.product,
  });

  @override
  State<AddEditProductScreen> createState() =>
      _AddEditProductScreenState();
}

class _OptionRow {
  final TextEditingController name;
  final TextEditingController price;
  final TextEditingController qty;
  _OptionRow({String name = '', String price = '', String qty = ''})
      : name = TextEditingController(text: name),
        price = TextEditingController(text: price),
        qty = TextEditingController(text: qty);
}

class _AddEditProductScreenState
    extends State<AddEditProductScreen> {
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();

  // 🆕 VARIANT OPTIONS
  bool _hasOptions = false;
  final _optionLabelController = TextEditingController(text: 'Weight');
  List<_OptionRow> _optionRows = [];

  final ProductRepository _productRepository =
      ProductRepository();
  final ProductStorageService _storageService =
      ProductStorageService();
  final ImagePicker _picker = ImagePicker();

  bool _loading = false;

  // -------------------------------
  // DELIVERY OVERRIDE STATE
  // -------------------------------
  bool _overrideDelivery = false;
  String _deliveryUnit = 'hours'; // minutes | hours | days
  final TextEditingController _deliveryMinController =
      TextEditingController();
  final TextEditingController _deliveryMaxController =
      TextEditingController();

  int _toMinutes(int value, String unit) {
    switch (unit) {
      case 'minutes':
        return value;
      case 'hours':
        return value * 60;
      case 'days':
        return value * 1440;
      default:
        return value;
    }
  }

  // Shared canonical list — see lib/config/categories.dart
  final List<String> _categories = kProductCategories;

  String? _selectedCategory;

  // -------------------------------
  // IMAGE STATE
  // -------------------------------
  static const int _maxImages = 4;
  List<XFile> _selectedImages = [];
  List<String> _uploadedImageUrls = [];
  List<String> _existingImages = [];

  int _coverIndex = 0;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();

    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _priceController.text =
          widget.product!.price.toString();
      _quantityController.text =
          widget.product!.quantity.toString();
      _categoryController.text =
          widget.product!.category;
      _descriptionController.text =
          widget.product!.description;

      // Normalise legacy values ("Groceries", "Clothing"…) to the canonical
      // list so the dropdown has a matching item; unknown -> null.
      final norm = normalizeCategory(widget.product!.category);
      _selectedCategory = _categories.contains(norm) ? norm : null;

      _existingImages = List.from(widget.product!.images);

      _coverIndex = widget.product!.images
          .indexOf(widget.product!.coverImage);

      if (_coverIndex < 0) _coverIndex = 0;

      // 🆕 LOAD DELIVERY OVERRIDE IF EXISTS
      if (widget.product!.deliveryMinMinutes != null) {
        _overrideDelivery = true;
        _deliveryUnit =
            widget.product!.deliveryUnit ?? 'hours';
        _deliveryMinController.text =
            widget.product!.deliveryMinValue?.toString() ?? '';
        _deliveryMaxController.text =
            widget.product!.deliveryMaxValue?.toString() ?? '';
      }

      // 🆕 LOAD VARIANT OPTIONS IF EXIST
      if (widget.product!.hasOptions) {
        _hasOptions = true;
        _optionLabelController.text =
            widget.product!.optionLabel ?? 'Option';
        _optionRows = widget.product!.options
            .map((o) => _OptionRow(
                  name: o.name,
                  price: o.price.toString(),
                  qty: o.quantity.toString(),
                ))
            .toList();
      }
    }
  }

  // -------------------------------
  // PICK IMAGES (MAX 4)
  // -------------------------------
  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage();

    if (images.isEmpty) return;

    if (images.length > _maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can upload maximum 4 images'),
        ),
      );
      return;
    }

    setState(() {
      _selectedImages = images;
      _coverIndex = 0;
    });
  }

  // -------------------------------
  // REMOVE IMAGE
  // -------------------------------
  void _removeImage(int index) {
    setState(() {
      if (_selectedImages.isNotEmpty) {
        _selectedImages.removeAt(index);
      } else {
        _existingImages.removeAt(index);
      }

      if (_coverIndex >=
          (_selectedImages.isNotEmpty
              ? _selectedImages.length
              : _existingImages.length)) {
        _coverIndex = 0;
      }
    });
  }

  // -------------------------------
  // UPLOAD IMAGES
  // -------------------------------
  Future<void> _uploadImages(String productId) async {
    _uploadedImageUrls.clear();
    _uploadProgress = 0;

    for (int i = 0; i < _selectedImages.length; i++) {
      final file = File(_selectedImages[i].path);

      final task =
          _storageService.uploadProductImageWithProgress(
        file: file,
        shopId: widget.shopId,
        productId: productId,
        index: i,
      );

      task.snapshotEvents.listen((event) {
        if (event.totalBytes > 0) {
          setState(() {
            _uploadProgress =
                event.bytesTransferred /
                event.totalBytes;
          });
        }
      });

      final snapshot = await task;
      final url = await snapshot.ref.getDownloadURL();
      _uploadedImageUrls.add(url);
    }
  }

  // -------------------------------
  // SAVE PRODUCT
  // -------------------------------
  Future<void> _saveProduct() async {
    if (_nameController.text.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    // 🆕 Resolve price / quantity / options.
    double price;
    int quantity;
    List<ProductOption> options = [];

    if (_hasOptions && _optionRows.isNotEmpty) {
      for (final r in _optionRows) {
        final n = r.name.text.trim();
        final p = double.tryParse(r.price.text);
        final q = int.tryParse(r.qty.text);
        if (n.isEmpty || p == null || p < 0 || q == null || q < 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Every option needs a name, price and stock')),
          );
          return;
        }
        options.add(ProductOption(name: n, price: p, quantity: q));
      }
      if (options.map((o) => o.name).toSet().length != options.length) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Option names must be unique')),
        );
        return;
      }
      price = options.map((o) => o.price).reduce((a, b) => a < b ? a : b);
      quantity = options.fold(0, (s, o) => s + o.quantity);
    } else {
      price = double.tryParse(_priceController.text) ?? -1;
      quantity = int.tryParse(_quantityController.text) ?? 0;
      if (price < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid price')),
        );
        return;
      }
    }

    int? minVal;
    int? maxVal;

    if (_overrideDelivery) {
      minVal = int.tryParse(_deliveryMinController.text);
      maxVal = int.tryParse(_deliveryMaxController.text);

      if (minVal == null ||
          maxVal == null ||
          minVal <= 0 ||
          maxVal < minVal) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Invalid delivery time')),
        );
        return;
      }
    }

    setState(() => _loading = true);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final user = await UserRepository().getUser(uid);

    if (user.societyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Society not found for user'),
        ),
      );
      setState(() => _loading = false);
      return;
    }

    final productId = widget.product?.id ??
        DateTime.now().millisecondsSinceEpoch.toString();

    if (_selectedImages.isNotEmpty) {
      await _uploadImages(productId);
    }

    final List<String> imagesToSave =
        _uploadedImageUrls.isNotEmpty
            ? _uploadedImageUrls
            : _existingImages;

    final coverImage =
        imagesToSave.isNotEmpty
            ? imagesToSave[_coverIndex]
            : '';

    _categoryController.text = _selectedCategory!;

    if (widget.product == null) {
      await _productRepository.createProduct(
        shopId: widget.shopId,
        sellerId: uid,
        societyId: user.societyId,
        name: _nameController.text.trim(),
        price: price,
        quantity: quantity,
        category: _categoryController.text.trim(),
        description:
            _descriptionController.text.trim(),
        images: imagesToSave,
        coverImage: coverImage,
        deliveryUnit: _overrideDelivery ? _deliveryUnit : null,
        deliveryMinValue: minVal,
        deliveryMaxValue: maxVal,
        deliveryMinMinutes: _overrideDelivery
            ? _toMinutes(minVal!, _deliveryUnit)
            : null,
        deliveryMaxMinutes: _overrideDelivery
            ? _toMinutes(maxVal!, _deliveryUnit)
            : null,
        optionLabel: _hasOptions
            ? (_optionLabelController.text.trim().isEmpty
                ? 'Option'
                : _optionLabelController.text.trim())
            : null,
        options: options,
      );
    } else {
      final updated = widget.product!.copyWith(
        name: _nameController.text.trim(),
        price: price,
        quantity: quantity,
        category: _categoryController.text.trim(),
        description:
            _descriptionController.text.trim(),
        images: imagesToSave,
        coverImage: coverImage,
        deliveryUnit: _overrideDelivery ? _deliveryUnit : null,
        deliveryMinValue: minVal,
        deliveryMaxValue: maxVal,
        deliveryMinMinutes: _overrideDelivery
            ? _toMinutes(minVal!, _deliveryUnit)
            : null,
        deliveryMaxMinutes: _overrideDelivery
            ? _toMinutes(maxVal!, _deliveryUnit)
            : null,
        optionLabel: _hasOptions
            ? (_optionLabelController.text.trim().isEmpty
                ? 'Option'
                : _optionLabelController.text.trim())
            : '',
        options: options,
      );

      await _productRepository.updateProduct(updated);
    }

    Navigator.pop(context, true);
  }

  // -------------------------------
  // UI
  // -------------------------------
  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;

    final imagesToShow =
        _selectedImages.isNotEmpty
            ? _selectedImages.map((e) => e.path).toList()
            : _existingImages;

    final isLocal = _selectedImages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Product' : 'Add Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration:
                  const InputDecoration(
                      labelText: 'Product Name'),
            ),

            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration:
                  const InputDecoration(labelText: 'Category'),
              items: _categories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),

            if (!_hasOptions) ...[
              TextField(
                controller: _priceController,
                decoration:
                    const InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: _quantityController,
                decoration: const InputDecoration(
                    labelText: 'Available Quantity'),
                keyboardType: TextInputType.number,
              ),
            ],

            const SizedBox(height: 12),

            // 🆕 VARIANT OPTIONS
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sizes / weights / colours'),
              subtitle: const Text('One listing, buyer picks an option'),
              value: _hasOptions,
              onChanged: (val) {
                setState(() {
                  _hasOptions = val;
                  if (val && _optionRows.isEmpty) {
                    _optionRows = [
                      _OptionRow(
                        price: _priceController.text,
                        qty: _quantityController.text,
                      )
                    ];
                  }
                });
              },
            ),

            if (_hasOptions) ...[
              TextField(
                controller: _optionLabelController,
                decoration: const InputDecoration(
                    labelText: 'Option type (Weight / Size / Colour)'),
              ),
              const SizedBox(height: 8),
              ..._optionRows.asMap().entries.map((e) {
                final i = e.key;
                final row = e.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: row.name,
                          decoration: const InputDecoration(
                              labelText: 'Name', hintText: '500g'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: row.price,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: '₹'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: row.qty,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Stock'),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () =>
                            setState(() => _optionRows.removeAt(i)),
                      ),
                    ],
                  ),
                );
              }),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Add option'),
                  onPressed: () =>
                      setState(() => _optionRows.add(_OptionRow())),
                ),
              ),
            ],

            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration:
                  const InputDecoration(
                      labelText: 'Description'),
            ),

            const SizedBox(height: 24),

            SwitchListTile(
              title: const Text('Override Delivery Time'),
              value: _overrideDelivery,
              onChanged: (val) {
                setState(() => _overrideDelivery = val);
              },
            ),

            if (_overrideDelivery) ...[
              DropdownButtonFormField<String>(
                value: _deliveryUnit,
                decoration:
                    const InputDecoration(labelText: 'Delivery Unit'),
                items: const [
                  DropdownMenuItem(
                      value: 'minutes', child: Text('Minutes')),
                  DropdownMenuItem(
                      value: 'hours', child: Text('Hours')),
                  DropdownMenuItem(
                      value: 'days', child: Text('Days')),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  setState(() => _deliveryUnit = val);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _deliveryMinController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Minimum'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _deliveryMaxController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Maximum'),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            if (imagesToShow.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics:
                    const NeverScrollableScrollPhysics(),
                itemCount: imagesToShow.length,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemBuilder: (_, index) {
                  return GestureDetector(
                    onTap: () =>
                        setState(() => _coverIndex = index),
                    child: Stack(
                      children: [
                        isLocal
                            ? Image.file(
                                File(imagesToShow[index]),
                                fit: BoxFit.cover,
                                width: double.infinity,
                              )
                            : Image.network(
                                imagesToShow[index],
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                        if (_coverIndex == index)
                          const Positioned(
                            top: 6,
                            left: 6,
                            child: Icon(Icons.star,
                                color: Colors.orange),
                          ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: GestureDetector(
                            onTap: () =>
                                _removeImage(index),
                            child: const Icon(
                              Icons.close,
                              color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

            if (_uploadProgress > 0 &&
                _uploadProgress < 1)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    LinearProgressIndicator(
                        value: _uploadProgress),
                    const SizedBox(height: 4),
                    Text(
                        'Uploading ${(100 * _uploadProgress).toInt()}%'),
                  ],
                ),
              ),

            ElevatedButton.icon(
              icon: const Icon(Icons.collections),
              label: const Text('Select Product Images'),
              onPressed: _pickImages,
            ),

            const SizedBox(height: 24),

            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _saveProduct,
                    child: const Text('Save'),
                  ),
          ],
        ),
      ),
    );
  }
}
