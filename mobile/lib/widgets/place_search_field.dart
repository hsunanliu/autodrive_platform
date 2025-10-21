// mobile/lib/widgets/place_search_field.dart

import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:latlong2/latlong.dart';
import '../services/geocoding_service.dart';

class PlaceSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Function(PlaceSuggestion) onPlaceSelected;
  final LatLng? userLocation; // 用於優先顯示附近結果

  const PlaceSearchField({
    Key? key,
    required this.controller,
    required this.hintText,
    required this.onPlaceSelected,
    this.userLocation,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TypeAheadField<PlaceSuggestion>(
      textFieldConfiguration: TextFieldConfiguration(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.white54),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70),
                  onPressed: () {
                    controller.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(0xFF2E2E2E),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
      suggestionsCallback: (pattern) async {
        if (pattern.length < 2) return [];
        return await GeocodingService.searchPlaces(
          pattern,
          proximity: userLocation,
        );
      },
      itemBuilder: (context, suggestion) {
        return ListTile(
          leading: Text(
            suggestion.icon,
            style: const TextStyle(fontSize: 24),
          ),
          title: Text(
            suggestion.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            suggestion.fullAddress,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
      onSuggestionSelected: (suggestion) {
        controller.text = suggestion.name;
        onPlaceSelected(suggestion);
      },
      noItemsFoundBuilder: (context) {
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_off, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text(
                  '找不到相關地點',
                  style: TextStyle(color: Colors.grey),
                ),
                SizedBox(height: 4),
                Text(
                  '試試輸入更具體的地址或景點名稱',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
      loadingBuilder: (context) {
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
      errorBuilder: (context, error) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              '搜尋時發生錯誤',
              style: TextStyle(color: Colors.red.shade300),
            ),
          ),
        );
      },
      // 自定義建議框樣式
      suggestionsBoxDecoration: SuggestionsBoxDecoration(
        borderRadius: BorderRadius.circular(12),
        elevation: 8,
        color: Colors.white,
      ),
      // 動畫設置
      animationDuration: const Duration(milliseconds: 200),
      // 延遲搜尋（避免過於頻繁的 API 調用）
      debounceDuration: const Duration(milliseconds: 400),
    );
  }
}
