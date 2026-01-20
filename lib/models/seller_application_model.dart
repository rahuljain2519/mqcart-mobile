class SellerApplicationModel {
  final String uid;

  // Business info
  final String shopName;
  final String category;
  final String description;
  final String businessType; // individual | proprietorship | pvt_ltd | llp

  // Identity & compliance
  final String panNumber;
  final String aadhaarLast4; // 🔐 only last 4 digits
  final String? gstin; // optional

  // Address
  final String addressLine;
  final String city;
  final String state;
  final String pincode;

  // Bank (optional but recommended)
  final String? bankAccountNumber;
  final String? ifscCode;
  final String? bankName;

  // System fields
  final String status; // pending | approved | rejected
  final DateTime createdAt;

  SellerApplicationModel({
    required this.uid,
    required this.shopName,
    required this.category,
    required this.description,
    required this.businessType,
    required this.panNumber,
    required this.aadhaarLast4,
    this.gstin,
    required this.addressLine,
    required this.city,
    required this.state,
    required this.pincode,
    this.bankAccountNumber,
    this.ifscCode,
    this.bankName,
    this.status = 'pending',
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'shopName': shopName,
      'category': category,
      'description': description,
      'businessType': businessType,
      'panNumber': panNumber,
      'aadhaarLast4': aadhaarLast4,
      'gstin': gstin,
      'addressLine': addressLine,
      'city': city,
      'state': state,
      'pincode': pincode,
      'bankAccountNumber': bankAccountNumber,
      'ifscCode': ifscCode,
      'bankName': bankName,
      'status': status,
      'createdAt': createdAt,
    };
  }

  factory SellerApplicationModel.fromJson(
      Map<String, dynamic> json) {
    return SellerApplicationModel(
      uid: json['uid'],
      shopName: json['shopName'],
      category: json['category'],
      description: json['description'],
      businessType: json['businessType'],
      panNumber: json['panNumber'],
      aadhaarLast4: json['aadhaarLast4'],
      gstin: json['gstin'],
      addressLine: json['addressLine'],
      city: json['city'],
      state: json['state'],
      pincode: json['pincode'],
      bankAccountNumber: json['bankAccountNumber'],
      ifscCode: json['ifscCode'],
      bankName: json['bankName'],
      status: json['status'],
      createdAt: json['createdAt'].toDate(),
    );
  }
}
