enum CardStyle { legacy, modern }

class SettingModel {
  final bool isDarkTheme;
  final CardStyle cardStyle;

  SettingModel({
    this.isDarkTheme = false,
    this.cardStyle = CardStyle.legacy,
  });

  SettingModel copyWith({bool? isDarkTheme, CardStyle? cardStyle}) =>
      SettingModel(
        isDarkTheme: isDarkTheme ?? this.isDarkTheme,
        cardStyle: cardStyle ?? this.cardStyle,
      );
}
