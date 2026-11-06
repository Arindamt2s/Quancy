class InspectionMenu {
  final int id;
  final String title;
  final String icon;
  final List<MenuCategory> categories;
  final List<MenuSubCategory> subCategories;

  InspectionMenu({
    required this.id,
    required this.title,
    required this.icon,
    required this.categories,
    required this.subCategories,
  });

  bool get hasCategories => categories.isNotEmpty;

  factory InspectionMenu.fromJson(Map<String, dynamic> json) {
    return InspectionMenu(
      id: json['id'],
      title: json['title'] ?? '',
      icon: json['icon'] ?? '',
      categories: (json['categories'] as List? ?? [])
          .map((e) => MenuCategory.fromJson(e))
          .toList(),
      subCategories: (json['subCategories'] as List? ?? [])
          .map((e) => MenuSubCategory.fromJson(e))
          .toList(),
    );
  }
}

class MenuCategory {
  final int id;
  final String title;
  final String icon;
  final List<MenuSubCategory> subCategories;

  MenuCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.subCategories,
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id'],
      title: json['title'] ?? '',
      icon: json['icon'] ?? '',
      subCategories: (json['subCategories'] as List? ?? [])
          .map((e) => MenuSubCategory.fromJson(e))
          .toList(),
    );
  }
}

class MenuSubCategory {
  final int id;
  final String title;
  final String icon;

  MenuSubCategory({required this.id, required this.title, required this.icon});

  factory MenuSubCategory.fromJson(Map<String, dynamic> json) {
    return MenuSubCategory(
      id: json['id'],
      title: json['title'] ?? '',
      icon: json['icon'] ?? '',
    );
  }
}