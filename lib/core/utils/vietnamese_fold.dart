// So khớp tìm kiếm không phân biệt dấu tiếng Việt và hoa thường: gõ "ha noi" vẫn ra "Hà Nội".

/// Bỏ dấu tiếng Việt và viết thường. Mỗi ký tự vào cho đúng một ký tự ra, nên vị trí khớp trong chuỗi đã bỏ dấu
/// dùng thẳng được trên chuỗi gốc để tô đậm đoạn khớp.
String foldVietnamese(String text) {
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < text.length; i++) {
    final String char = text[i];
    final String lower = char.toLowerCase();
    // Vài ký tự hiếm viết thường ra 2 ký tự (vd "İ"): giữ nguyên để không lệch vị trí
    final String base = lower.length == 1 ? lower : char;
    out.write(_vietnameseBase[base] ?? base);
  }
  return out.toString();
}

final Map<String, String> _vietnameseBase = {
  for (final MapEntry<String, String> group in const {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  }.entries)
    for (final String accented in group.value.split('')) accented: group.key,
};
