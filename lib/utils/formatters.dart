import 'package:intl/intl.dart';

final moneyFormat = MoneyFormatter();
final compactDateFormat = DateFormat('dd MMM, hh:mm a');
final dateFormat = DateFormat('dd MMM yyyy');

String newId(String prefix) =>
    '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

class MoneyFormatter {
  NumberFormat _format = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);

  void setCurrency(String currency) {
    _format = NumberFormat.currency(
      symbol: currencySymbol(currency),
      decimalDigits: 0,
    );
  }

  String format(num value) => _format.format(value);
}

String currencySymbol(String currency) {
  final code = currency.toUpperCase();
  for (final option in supportedCurrencyOptions) {
    if (option.code == code) return option.symbol;
  }
  try {
    return '${NumberFormat.simpleCurrency(name: code).currencySymbol} ';
  } catch (_) {
    return '$code ';
  }
}

class CurrencyOption {
  const CurrencyOption(this.code, this.name, this.symbol);

  final String code;
  final String name;
  final String symbol;

  String get label => '$code - $name';
}

const supportedCurrencyOptions = [
  CurrencyOption('AED', 'United Arab Emirates Dirham', 'د.إ '),
  CurrencyOption('AFN', 'Afghan Afghani', '؋ '),
  CurrencyOption('ALL', 'Albanian Lek', 'L '),
  CurrencyOption('AMD', 'Armenian Dram', '֏ '),
  CurrencyOption('ANG', 'Netherlands Antillean Guilder', 'ƒ '),
  CurrencyOption('AOA', 'Angolan Kwanza', 'Kz '),
  CurrencyOption('ARS', 'Argentine Peso', r'$ '),
  CurrencyOption('AUD', 'Australian Dollar', r'A$ '),
  CurrencyOption('AWG', 'Aruban Florin', 'ƒ '),
  CurrencyOption('AZN', 'Azerbaijani Manat', '₼ '),
  CurrencyOption('BAM', 'Bosnia-Herzegovina Convertible Mark', 'KM '),
  CurrencyOption('BBD', 'Barbadian Dollar', r'Bds$ '),
  CurrencyOption('BDT', 'Bangladeshi Taka', '৳ '),
  CurrencyOption('BGN', 'Bulgarian Lev', 'лв '),
  CurrencyOption('BHD', 'Bahraini Dinar', '.د.ب '),
  CurrencyOption('BIF', 'Burundian Franc', 'FBu '),
  CurrencyOption('BMD', 'Bermudian Dollar', r'BD$ '),
  CurrencyOption('BND', 'Brunei Dollar', r'B$ '),
  CurrencyOption('BOB', 'Bolivian Boliviano', 'Bs '),
  CurrencyOption('BRL', 'Brazilian Real', r'R$ '),
  CurrencyOption('BSD', 'Bahamian Dollar', r'B$ '),
  CurrencyOption('BTN', 'Bhutanese Ngultrum', 'Nu '),
  CurrencyOption('BWP', 'Botswana Pula', 'P '),
  CurrencyOption('BYN', 'Belarusian Ruble', 'Br '),
  CurrencyOption('BZD', 'Belize Dollar', r'BZ$ '),
  CurrencyOption('CAD', 'Canadian Dollar', r'C$ '),
  CurrencyOption('CDF', 'Congolese Franc', 'FC '),
  CurrencyOption('CHF', 'Swiss Franc', 'CHF '),
  CurrencyOption('CLP', 'Chilean Peso', r'CLP$ '),
  CurrencyOption('CNY', 'Chinese Yuan', '¥ '),
  CurrencyOption('COP', 'Colombian Peso', r'COL$ '),
  CurrencyOption('CRC', 'Costa Rican Colon', '₡ '),
  CurrencyOption('CUP', 'Cuban Peso', r'$MN '),
  CurrencyOption('CVE', 'Cape Verdean Escudo', r'Esc '),
  CurrencyOption('CZK', 'Czech Koruna', 'Kč '),
  CurrencyOption('DJF', 'Djiboutian Franc', 'Fdj '),
  CurrencyOption('DKK', 'Danish Krone', 'kr '),
  CurrencyOption('DOP', 'Dominican Peso', r'RD$ '),
  CurrencyOption('DZD', 'Algerian Dinar', 'دج '),
  CurrencyOption('EGP', 'Egyptian Pound', 'E£ '),
  CurrencyOption('ERN', 'Eritrean Nakfa', 'Nfk '),
  CurrencyOption('ETB', 'Ethiopian Birr', 'Br '),
  CurrencyOption('EUR', 'Euro', '€'),
  CurrencyOption('FJD', 'Fijian Dollar', r'FJ$ '),
  CurrencyOption('FKP', 'Falkland Islands Pound', '£ '),
  CurrencyOption('GBP', 'British Pound Sterling', '£'),
  CurrencyOption('GEL', 'Georgian Lari', '₾ '),
  CurrencyOption('GHS', 'Ghanaian Cedi', '₵ '),
  CurrencyOption('GIP', 'Gibraltar Pound', '£ '),
  CurrencyOption('GMD', 'Gambian Dalasi', 'D '),
  CurrencyOption('GNF', 'Guinean Franc', 'FG '),
  CurrencyOption('GTQ', 'Guatemalan Quetzal', 'Q '),
  CurrencyOption('GYD', 'Guyanese Dollar', r'G$ '),
  CurrencyOption('HKD', 'Hong Kong Dollar', r'HK$ '),
  CurrencyOption('HNL', 'Honduran Lempira', 'L '),
  CurrencyOption('HTG', 'Haitian Gourde', 'G '),
  CurrencyOption('HUF', 'Hungarian Forint', 'Ft '),
  CurrencyOption('IDR', 'Indonesian Rupiah', 'Rp '),
  CurrencyOption('ILS', 'Israeli New Shekel', '₪ '),
  CurrencyOption('INR', 'Indian Rupee', '₹'),
  CurrencyOption('IQD', 'Iraqi Dinar', 'ع.د '),
  CurrencyOption('IRR', 'Iranian Rial', '﷼ '),
  CurrencyOption('ISK', 'Icelandic Krona', 'kr '),
  CurrencyOption('JMD', 'Jamaican Dollar', r'J$ '),
  CurrencyOption('JOD', 'Jordanian Dinar', 'د.ا '),
  CurrencyOption('JPY', 'Japanese Yen', '¥ '),
  CurrencyOption('KES', 'Kenyan Shilling', 'KSh '),
  CurrencyOption('KGS', 'Kyrgyzstani Som', 'сом '),
  CurrencyOption('KHR', 'Cambodian Riel', '៛ '),
  CurrencyOption('KMF', 'Comorian Franc', 'CF '),
  CurrencyOption('KRW', 'South Korean Won', '₩ '),
  CurrencyOption('KWD', 'Kuwaiti Dinar', 'د.ك '),
  CurrencyOption('KYD', 'Cayman Islands Dollar', r'CI$ '),
  CurrencyOption('KZT', 'Kazakhstani Tenge', '₸ '),
  CurrencyOption('LAK', 'Lao Kip', '₭ '),
  CurrencyOption('LBP', 'Lebanese Pound', 'ل.ل '),
  CurrencyOption('LKR', 'Sri Lankan Rupee', 'Rs '),
  CurrencyOption('LRD', 'Liberian Dollar', r'L$ '),
  CurrencyOption('LSL', 'Lesotho Loti', 'L '),
  CurrencyOption('LYD', 'Libyan Dinar', 'ل.د '),
  CurrencyOption('MAD', 'Moroccan Dirham', 'د.م. '),
  CurrencyOption('MDL', 'Moldovan Leu', 'L '),
  CurrencyOption('MGA', 'Malagasy Ariary', 'Ar '),
  CurrencyOption('MKD', 'Macedonian Denar', 'ден '),
  CurrencyOption('MMK', 'Myanmar Kyat', 'K '),
  CurrencyOption('MNT', 'Mongolian Tugrik', '₮ '),
  CurrencyOption('MOP', 'Macanese Pataca', r'MOP$ '),
  CurrencyOption('MRU', 'Mauritanian Ouguiya', 'UM '),
  CurrencyOption('MUR', 'Mauritian Rupee', 'Rs '),
  CurrencyOption('MVR', 'Maldivian Rufiyaa', 'Rf '),
  CurrencyOption('MWK', 'Malawian Kwacha', 'MK '),
  CurrencyOption('MXN', 'Mexican Peso', r'Mex$ '),
  CurrencyOption('MYR', 'Malaysian Ringgit', 'RM '),
  CurrencyOption('MZN', 'Mozambican Metical', 'MT '),
  CurrencyOption('NAD', 'Namibian Dollar', r'N$ '),
  CurrencyOption('NGN', 'Nigerian Naira', '₦ '),
  CurrencyOption('NIO', 'Nicaraguan Cordoba', r'C$ '),
  CurrencyOption('NOK', 'Norwegian Krone', 'kr '),
  CurrencyOption('NPR', 'Nepalese Rupee', 'Rs '),
  CurrencyOption('NZD', 'New Zealand Dollar', r'NZ$ '),
  CurrencyOption('OMR', 'Omani Rial', 'ر.ع. '),
  CurrencyOption('PAB', 'Panamanian Balboa', 'B/. '),
  CurrencyOption('PEN', 'Peruvian Sol', 'S/ '),
  CurrencyOption('PGK', 'Papua New Guinean Kina', 'K '),
  CurrencyOption('PHP', 'Philippine Peso', '₱ '),
  CurrencyOption('PKR', 'Pakistani Rupee', 'Rs '),
  CurrencyOption('PLN', 'Polish Zloty', 'zł '),
  CurrencyOption('PYG', 'Paraguayan Guarani', '₲ '),
  CurrencyOption('QAR', 'Qatari Riyal', 'ر.ق '),
  CurrencyOption('RON', 'Romanian Leu', 'lei '),
  CurrencyOption('RSD', 'Serbian Dinar', 'дин '),
  CurrencyOption('RUB', 'Russian Ruble', '₽ '),
  CurrencyOption('RWF', 'Rwandan Franc', 'RF '),
  CurrencyOption('SAR', 'Saudi Riyal', '﷼ '),
  CurrencyOption('SBD', 'Solomon Islands Dollar', r'SI$ '),
  CurrencyOption('SCR', 'Seychellois Rupee', 'Rs '),
  CurrencyOption('SDG', 'Sudanese Pound', 'ج.س. '),
  CurrencyOption('SEK', 'Swedish Krona', 'kr '),
  CurrencyOption('SGD', 'Singapore Dollar', r'S$ '),
  CurrencyOption('SHP', 'Saint Helena Pound', '£ '),
  CurrencyOption('SLE', 'Sierra Leonean Leone', 'Le '),
  CurrencyOption('SOS', 'Somali Shilling', 'Sh '),
  CurrencyOption('SRD', 'Surinamese Dollar', r'Sr$ '),
  CurrencyOption('SSP', 'South Sudanese Pound', '£ '),
  CurrencyOption('STN', 'Sao Tome and Principe Dobra', 'Db '),
  CurrencyOption('SYP', 'Syrian Pound', '£S '),
  CurrencyOption('SZL', 'Eswatini Lilangeni', 'E '),
  CurrencyOption('THB', 'Thai Baht', '฿ '),
  CurrencyOption('TJS', 'Tajikistani Somoni', 'SM '),
  CurrencyOption('TMT', 'Turkmenistani Manat', 'm '),
  CurrencyOption('TND', 'Tunisian Dinar', 'د.ت '),
  CurrencyOption('TOP', 'Tongan Paanga', r'T$ '),
  CurrencyOption('TRY', 'Turkish Lira', '₺ '),
  CurrencyOption('TTD', 'Trinidad and Tobago Dollar', r'TT$ '),
  CurrencyOption('TWD', 'New Taiwan Dollar', r'NT$ '),
  CurrencyOption('TZS', 'Tanzanian Shilling', 'TSh '),
  CurrencyOption('UAH', 'Ukrainian Hryvnia', '₴ '),
  CurrencyOption('UGX', 'Ugandan Shilling', 'USh '),
  CurrencyOption('USD', 'United States Dollar', r'$'),
  CurrencyOption('UYU', 'Uruguayan Peso', r'$U '),
  CurrencyOption('UZS', 'Uzbekistani Som', 'soʻm '),
  CurrencyOption('VES', 'Venezuelan Bolivar', 'Bs. '),
  CurrencyOption('VND', 'Vietnamese Dong', '₫ '),
  CurrencyOption('VUV', 'Vanuatu Vatu', 'VT '),
  CurrencyOption('WST', 'Samoan Tala', 'T '),
  CurrencyOption('XAF', 'Central African CFA Franc', 'FCFA '),
  CurrencyOption('XCD', 'East Caribbean Dollar', r'EC$ '),
  CurrencyOption('XOF', 'West African CFA Franc', 'CFA '),
  CurrencyOption('XPF', 'CFP Franc', '₣ '),
  CurrencyOption('YER', 'Yemeni Rial', '﷼ '),
  CurrencyOption('ZAR', 'South African Rand', 'R '),
  CurrencyOption('ZMW', 'Zambian Kwacha', 'ZK '),
  CurrencyOption('ZWG', 'Zimbabwe Gold', 'ZiG '),
];

final supportedCurrencies = [
  for (final option in supportedCurrencyOptions) option.code,
];
