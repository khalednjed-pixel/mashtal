// Shop photos bundled with the app (assets/plants/). Real photos of each
// species from Wikimedia Commons; studio photos have the background removed
// and are marked as edited. Keep the author and licence with each photo.
// How to add one: docs/plant-data.md.

class ShopPhoto {
  const ShopPhoto({required this.asset, required this.file, required this.author, required this.licence, this.licenceUrl, this.edited = false, this.aiGenerated = false, this.studio = false});
  final String asset;

  /// File name on Wikimedia Commons.
  final String file;
  final String author;
  final String licence;
  final String? licenceUrl;

  /// Background removed or replaced.
  final bool edited;

  /// An AI illustration of the species (made from this reference photo), not a photo.
  final bool aiGenerated;

  /// Plain white studio background: shown whole on white, not on a blur.
  final bool studio;
}

const Map<String, ShopPhoto> shopPhotos = {
  'p01': ShopPhoto(asset: 'assets/plants/p01.jpg', file: 'Prosopis cineraria kz01.jpg', author: 'Krzysztof Ziarnek, Kenraiz', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0', aiGenerated: true),
  'p02': ShopPhoto(asset: 'assets/plants/p02.jpg', file: 'Acacia (Vachellia tortilis), parque nacional Serengueti, Tanzania, 2024-05-26, DD 26.jpg', author: 'Diego Delso', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0', aiGenerated: true, studio: true),
  'p03': ShopPhoto(asset: 'assets/plants/p03.jpg', file: 'Ziziphus spina-christi kz09.jpg', author: 'Krzysztof Ziarnek, Kenraiz', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0', aiGenerated: true, studio: true),
  'p04': ShopPhoto(asset: 'assets/plants/p04.jpg', file: 'Phoenix dactylifera - খেজুর গাছ.jpg', author: 'Apurba Biswas', licence: 'CC0', licenceUrl: 'http://creativecommons.org/publicdomain/zero/1.0/deed.en'),
  'p05': ShopPhoto(asset: 'assets/plants/p05.jpg', file: 'Tamarix aphylla in Wagga Wagga.jpg', author: 'Bidgee', licence: 'CC BY-SA 2.5 au', licenceUrl: 'https://creativecommons.org/licenses/by-sa/2.5/au/deed.en'),
  'p06': ShopPhoto(asset: 'assets/plants/p06.jpg', file: 'Acacia gerrardii, habitus, Walter Sisulu NBT.jpg', author: 'JMK', licence: 'CC BY-SA 3.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/3.0'),
  'p07': ShopPhoto(asset: 'assets/plants/p07.jpg', file: 'Moringa peregrina kz06.jpg', author: 'Krzysztof Ziarnek, Kenraiz', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0'),
  'p08': ShopPhoto(asset: 'assets/plants/p08.jpg', file: 'Parkinsonia aculeata - Jarusalem thorn 01.jpg', author: 'Zeynel Cebeci', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0'),
  'p09': ShopPhoto(asset: 'assets/plants/p09.jpg', file: 'Albizia lebbeck tree 01.JPG', author: 'Forestowlet', licence: 'CC0', licenceUrl: 'http://creativecommons.org/publicdomain/zero/1.0/deed.en'),
  'p10': ShopPhoto(asset: 'assets/plants/p10.jpg', file: 'Delonix regia 4257.jpg', author: 'Anna Anichkova', licence: 'CC BY-SA 3.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/3.0'),
  'p11': ShopPhoto(asset: 'assets/plants/p11.jpg', file: 'Washingtonia filifera (Fairy Tale Park Gaziantep - Masal Parkı Gaziantep).IMG 1574.jpg', author: 'YG01', licence: 'CC BY 4.0', licenceUrl: 'https://creativecommons.org/licenses/by/4.0', aiGenerated: true),
  'p12': ShopPhoto(asset: 'assets/plants/p12.jpg', file: 'Dodonaea viscosa kz 06.jpg', author: 'Krzysztof Ziarnek, Kenraiz', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0', aiGenerated: true, studio: true),
  'p13': ShopPhoto(asset: 'assets/plants/p13.jpg', file: '(MHNT) Leucophyllum frutescens.jpg', author: 'Didier Descouens', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0'),
  'p14': ShopPhoto(asset: 'assets/plants/p14.jpg', file: 'Tecoma stans by Prahlad balaji 2.jpg', author: 'Prahlad balaji', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0', edited: true, studio: true),
  'p15': ShopPhoto(asset: 'assets/plants/p15.jpg', file: 'Oleander (Nerium oleander) habit.jpg', author: 'David E Mead', licence: 'CC0', licenceUrl: 'http://creativecommons.org/publicdomain/zero/1.0/deed.en', edited: true, studio: true),
  'p16': ShopPhoto(asset: 'assets/plants/p16.jpg', file: 'Bougainvillea spectabilis 3.jpg', author: 'George Muttathil Pulikurumba', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0', edited: true, studio: true),
  'p17': ShopPhoto(asset: 'assets/plants/p17.jpg', file: 'LantanaFlowerLeaves.jpg', author: 'Alvesgaspar', licence: 'CC BY-SA 3.0', licenceUrl: 'http://creativecommons.org/licenses/by-sa/3.0/'),
  'p18': ShopPhoto(asset: 'assets/plants/p18.jpg', file: 'Calotropis procera kz11.jpg', author: 'Krzysztof Ziarnek, Kenraiz', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0', edited: true, studio: true),
  'p19': ShopPhoto(asset: 'assets/plants/p19.jpg', file: 'Rhanterium epapposum — Arfaj, Kuwait National flower — I Love Q8.jpg', author: 'I ♥ Q8', licence: 'CC BY-SA 2.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/2.0'),
  'p20': ShopPhoto(asset: 'assets/plants/p20.jpg', file: 'Leptadenia pyrotechnica kz01.jpg', author: 'Krzysztof Ziarnek, Kenraiz', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0'),
  'p21': ShopPhoto(asset: 'assets/plants/p21.jpg', file: 'Caesalpinia gilliesii 1.jpg', author: 'Stan Shebs', licence: 'CC BY-SA 3.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/3.0'),
  'p22': ShopPhoto(asset: 'assets/plants/p22.jpg', file: 'Starr 010820-0009 Carissa macrocarpa.jpg', author: 'Forest & Kim Starr', licence: 'CC BY 3.0', licenceUrl: 'https://creativecommons.org/licenses/by/3.0'),
  'p23': ShopPhoto(asset: 'assets/plants/p23.jpg', file: 'Jasminum sambac in China.jpg', author: 'Dinkun Chen', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0'),
  'p24': ShopPhoto(asset: 'assets/plants/p24.jpg', file: 'Hibiscus rosa-sinensis 22.jpg', author: 'Vengolis', licence: 'CC BY-SA 3.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/3.0', aiGenerated: true, studio: true),
  'p25': ShopPhoto(asset: 'assets/plants/p25.jpg', file: 'Vitex agnus-castus kz04.jpg', author: 'Krzysztof Ziarnek, Kenraiz', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0'),
  'p26': ShopPhoto(asset: 'assets/plants/p26.jpg', file: 'Aloe Vera plant in a flowerpot.jpg', author: 'Sabina Bajracharya', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0', edited: true, studio: true),
  'p27': ShopPhoto(asset: 'assets/plants/p27.jpg', file: 'Variegated Century Plant -- Agave americana \'Marginata\'.jpg', author: 'Jim Evans', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0'),
  'p28': ShopPhoto(asset: 'assets/plants/p28.jpg', file: 'Portulacaria afra - Spekboom South Africa2.jpg', author: 'Abu Shawka', licence: 'CC0', licenceUrl: 'http://creativecommons.org/publicdomain/zero/1.0/deed.en'),
  'p29': ShopPhoto(asset: 'assets/plants/p29.jpg', file: 'Pennisetum setaceum kz01.jpg', author: 'Krzysztof Ziarnek, Kenraiz', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0'),
  'p30': ShopPhoto(asset: 'assets/plants/p30.jpg', file: 'Paspalum vaginatum (grass).jpg', author: 'Nalbarian', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0'),
  'p31': ShopPhoto(asset: 'assets/plants/p31.jpg', file: 'Sesuvium portulacastrum kz10.jpg', author: 'Krzysztof Ziarnek, Kenraiz', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0'),
  'p32': ShopPhoto(asset: 'assets/plants/p32.jpg', file: 'Rosmarinus officinalis 0001.JPG', author: 'H. Zell', licence: 'CC BY-SA 3.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/3.0'),
  'p33': ShopPhoto(asset: 'assets/plants/p33.jpg', file: 'Eland\'s Pea (Senna italica) (50111366221).jpg', author: 'Bernard DUPONT from FRANCE', licence: 'CC BY-SA 2.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/2.0'),
  'p34': ShopPhoto(asset: 'assets/plants/p34.jpg', file: 'Epipremnum aureum (Marble Queen) houseplant (2).png', author: 'Spnq', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0', edited: true, studio: true),
  'p35': ShopPhoto(asset: 'assets/plants/p35.jpg', file: 'Dracaena trifasciata 50695143.jpg', author: 'Ian Webb', licence: 'CC BY 4.0', licenceUrl: 'https://creativecommons.org/licenses/by/4.0'),
  'p36': ShopPhoto(asset: 'assets/plants/p36.jpg', file: 'Zamioculcas zamiifolia 1.jpg', author: 'User:WeFt', licence: 'CC BY-SA 3.0', licenceUrl: 'http://creativecommons.org/licenses/by-sa/3.0/', edited: true, studio: true),
  'p37': ShopPhoto(asset: 'assets/plants/p37.jpg', file: 'Cveće u saksiji 05.jpg', author: 'Ljiljana Sundać', licence: 'CC BY-SA 4.0', licenceUrl: 'https://creativecommons.org/licenses/by-sa/4.0'),
};
