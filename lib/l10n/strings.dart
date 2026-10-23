import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../state/app_state.dart';

/// Arabic (default) and English UI text (SF-33).
const Map<String, Map<String, String>> _strings = {
  'appName': {'ar': 'مشتل', 'en': 'Mashtal'},
  'tagline': {'ar': 'اعرف ما سينمو، واشتره، واعتنِ به', 'en': 'Know what will grow. Buy it. Keep it alive.'},
  'buyPlants': {'ar': 'شراء النباتات', 'en': 'Buy Plants'},
  'myGarden': {'ar': 'حديقتي', 'en': 'My Garden'},
  'cart': {'ar': 'السلة', 'en': 'Cart'},
  'account': {'ar': 'حسابي', 'en': 'Account'},
  'signIn': {'ar': 'تسجيل الدخول', 'en': 'Sign in'},
  'signOut': {'ar': 'تسجيل الخروج', 'en': 'Sign out'},
  'guest': {'ar': 'زائر', 'en': 'Guest'},
  'language': {'ar': 'اللغة', 'en': 'Language'},
  'switchLanguage': {'ar': 'English', 'en': 'العربية'},
  'searchHint': {'ar': 'ابحث باسم النبتة أو المشتل', 'en': 'Search by plant or nursery name'},
  'filters': {'ar': 'تصفية', 'en': 'Filters'},
  'clearFilters': {'ar': 'مسح التصفية', 'en': 'Clear filters'},
  'apply': {'ar': 'تطبيق', 'en': 'Apply'},
  'any': {'ar': 'الكل', 'en': 'Any'},
  'placement': {'ar': 'المكان', 'en': 'Place'},
  'sun': {'ar': 'الشمس', 'en': 'Sun'},
  'water': {'ar': 'الماء', 'en': 'Water'},
  'maxPrice': {'ar': 'أعلى سعر', 'en': 'Max price'},
  'city': {'ar': 'المدينة', 'en': 'City'},
  'plants': {'ar': 'النباتات', 'en': 'Plants'},
  'nurseries': {'ar': 'المشاتل', 'en': 'Nurseries'},
  'professionals': {'ar': 'المختصون', 'en': 'Professionals'},
  'noResults': {'ar': 'لا توجد نتائج. جرّب كلمة أخرى أو امسح التصفية.', 'en': 'No results. Try another word or clear the filters.'},
  'from': {'ar': 'من', 'en': 'from'},
  'sar': {'ar': 'ر.س', 'en': 'SAR'},
  'notAvailable': {'ar': 'غير متوفر', 'en': 'Not available'},
  'inStock': {'ar': 'متوفر', 'en': 'In stock'},
  'nurseriesCount': {'ar': 'مشاتل', 'en': 'nurseries'},
  'oneNursery': {'ar': 'مشتل واحد', 'en': '1 nursery'},
  'addToCart': {'ar': 'أضف للسلة', 'en': 'Add to cart'},
  'addedToCart': {'ar': 'أضيفت إلى السلة', 'en': 'Added to cart'},
  'whereToBuy': {'ar': 'أين تجدها', 'en': 'Where to buy'},
  'waterEvery': {'ar': 'الري كل', 'en': 'Water every'},
  'days': {'ar': 'أيام', 'en': 'days'},
  'toxicWarning': {'ar': 'سامة للأطفال أو الحيوانات الأليفة', 'en': 'Toxic to children or pets'},
  'source': {'ar': 'المصدر', 'en': 'Source'},
  'notGuideBacked': {'ar': 'ليست من الدليل الرسمي', 'en': 'Not from the official guide'},
  'rating': {'ar': 'التقييم', 'en': 'Rating'},
  'hours': {'ar': 'ساعات العمل', 'en': 'Opening hours'},
  'district': {'ar': 'الحي', 'en': 'District'},
  'cartEmpty': {'ar': 'سلتك فارغة', 'en': 'Your cart is empty'},
  'reserve': {'ar': 'احجز', 'en': 'Reserve'},
  'reserveSoon': {
    'ar': 'الحجز من المشاتل يصل في السبرنت الثالث. سلتك محفوظة.',
    'en': 'Reserving from nurseries arrives in Sprint 3. Your cart is saved.'
  },
  'signInToContinue': {'ar': 'سجّل الدخول للمتابعة', 'en': 'Sign in to continue'},
  'signInReason': {
    'ar': 'تحتاج حساباً لحجز النباتات واستخدام حديقتي. ستعود لنفس الصفحة بعد الدخول.',
    'en': 'You need an account to reserve plants and use My Garden. You will come back to this page afterwards.'
  },
  'gardenEmpty': {'ar': 'لا توجد نباتات في حديقتك بعد', 'en': 'No plants in your garden yet'},
  'gardenSoon': {
    'ar': 'النباتات التي تستلمها من المشتل ستظهر هنا تلقائياً (السبرنت الثالث).',
    'en': 'Plants you pick up from a nursery will appear here automatically (Sprint 3).'
  },
  'addManually': {'ar': 'أضف نبتة يدوياً', 'en': 'Add a plant manually'},
  'phoneNumber': {'ar': 'رقم الجوال', 'en': 'Mobile number'},
  'phoneHint': {'ar': '05XXXXXXXX', 'en': '05XXXXXXXX'},
  'sendCode': {'ar': 'أرسل الرمز', 'en': 'Send code'},
  'enterCode': {'ar': 'أدخل الرمز المكون من 6 أرقام', 'en': 'Enter the 6-digit code'},
  'codeSentTo': {'ar': 'أرسلنا رمزاً إلى', 'en': 'We sent a code to'},
  'verify': {'ar': 'تحقق', 'en': 'Verify'},
  'resendIn': {'ar': 'إعادة الإرسال بعد', 'en': 'Resend in'},
  'seconds': {'ar': 'ثانية', 'en': 's'},
  'resend': {'ar': 'أعد إرسال الرمز', 'en': 'Resend code'},
  'changeNumber': {'ar': 'تغيير الرقم', 'en': 'Change number'},
  'demoSms': {'ar': 'وضع العرض: رمز الرسالة هو', 'en': 'Demo mode: the SMS code is'},
  'err.invalid-phone': {'ar': 'أدخل رقم جوال سعودي صحيح يبدأ بـ 05', 'en': 'Enter a valid Saudi mobile number starting with 05'},
  'err.wrong-code': {'ar': 'الرمز غير صحيح. تأكد منه وحاول مرة أخرى.', 'en': 'The code is incorrect. Check it and try again.'},
  'err.code-expired': {'ar': 'انتهت صلاحية الرمز. اطلب رمزاً جديداً.', 'en': 'The code has expired. Request a new one.'},
  'err.no-code': {'ar': 'اطلب رمزاً أولاً.', 'en': 'Request a code first.'},
  'err.too-soon': {'ar': 'انتظر قليلاً قبل طلب رمز جديد.', 'en': 'Please wait before requesting a new code.'},
  'completeProfile': {'ar': 'أكمل حسابك', 'en': 'Complete your account'},
  'name': {'ar': 'الاسم', 'en': 'Name'},
  'nameRequired': {'ar': 'أدخل اسمك', 'en': 'Enter your name'},
  'create': {'ar': 'إنشاء الحساب', 'en': 'Create account'},
  'welcome': {'ar': 'أهلاً', 'en': 'Welcome'},
  'accessDenied': {'ar': 'لا تملك صلاحية لهذه الصفحة', 'en': 'You do not have access to that page'},
  'demoAccounts': {'ar': 'حسابات تجريبية', 'en': 'Demo accounts'},
  'demoAccountsHint': {
    'ar': 'أي رقم آخر يسجل كعميل جديد. يظهر الرمز على الشاشة بدلاً من رسالة SMS.',
    'en': 'Any other number registers as a new customer. The code is shown on screen instead of an SMS.'
  },
  'resetDemo': {'ar': 'إعادة ضبط بيانات العرض', 'en': 'Reset demo data'},
  'resetDone': {'ar': 'أعيدت البيانات التجريبية', 'en': 'Demo data restored'},
  'role': {'ar': 'الدور', 'en': 'Role'},
  // Nursery
  'myListings': {'ar': 'منتجاتي', 'en': 'My listings'},
  'reservations': {'ar': 'الحجوزات', 'en': 'Reservations'},
  'reservationsSoon': {'ar': 'طلبات الحجز تظهر هنا في السبرنت الثالث.', 'en': 'Reservation requests appear here in Sprint 3.'},
  'addListing': {'ar': 'أضف منتجاً', 'en': 'Add listing'},
  'editListing': {'ar': 'تعديل المنتج', 'en': 'Edit listing'},
  'choosePlant': {'ar': 'اختر النبتة من قائمة النباتات', 'en': 'Choose the plant from the plant list'},
  'price': {'ar': 'السعر (ر.س)', 'en': 'Price (SAR)'},
  'quantity': {'ar': 'الكمية', 'en': 'Quantity'},
  'hidden': {'ar': 'مخفي', 'en': 'Hidden'},
  'hideListing': {'ar': 'إخفاء عن العملاء', 'en': 'Hide from customers'},
  'save': {'ar': 'حفظ', 'en': 'Save'},
  'cancel': {'ar': 'إلغاء', 'en': 'Cancel'},
  'saved': {'ar': 'تم الحفظ', 'en': 'Saved'},
  'invalidPrice': {'ar': 'أدخل سعراً أكبر من صفر', 'en': 'Enter a price above zero'},
  'invalidQuantity': {'ar': 'أدخل كمية صفر أو أكثر', 'en': 'Enter a quantity of zero or more'},
  'plantRequired': {'ar': 'اختر نبتة', 'en': 'Choose a plant'},
  'alreadyListed': {'ar': 'هذه النبتة موجودة في منتجاتك، عدّلها بدلاً من إضافتها.', 'en': 'You already list this plant; edit it instead.'},
  'noListings': {'ar': 'لا توجد منتجات بعد. أضف أول نبتة.', 'en': 'No listings yet. Add your first plant.'},
  'pendingNursery': {
    'ar': 'مشتلك قيد المراجعة. منتجاتك لن تظهر للعملاء حتى يتم التحقق منه.',
    'en': 'Your nursery is under review. Your listings are hidden from customers until it is verified.'
  },
  'qtyShort': {'ar': 'الكمية', 'en': 'Qty'},
  // Admin
  'admin': {'ar': 'الإدارة', 'en': 'Admin'},
  'addNursery': {'ar': 'أضف مشتلاً', 'en': 'Add nursery'},
  'addProfessional': {'ar': 'أضف مختصاً', 'en': 'Add professional'},
  'nameAr': {'ar': 'الاسم بالعربية', 'en': 'Name in Arabic'},
  'nameEn': {'ar': 'الاسم بالإنجليزية', 'en': 'Name in English'},
  'services': {'ar': 'الخدمات', 'en': 'Services'},
  'required': {'ar': 'مطلوب', 'en': 'Required'},
  'status': {'ar': 'الحالة', 'en': 'Status'},
  'verify_action': {'ar': 'تحقق', 'en': 'Verify'},
  'suspend': {'ar': 'إيقاف', 'en': 'Suspend'},
  'setPending': {'ar': 'إرجاع للمراجعة', 'en': 'Back to pending'},
  'newPartnerPending': {
    'ar': 'يضاف كـ "قيد المراجعة" ولا يظهر للعملاء حتى تتحقق منه.',
    'en': 'Added as "pending" and hidden from customers until you verify it.'
  },
  'jobsDone': {'ar': 'مهمة منجزة', 'en': 'jobs done'},
  'priceRanges': {'ar': 'نطاقات الأسعار', 'en': 'Price ranges'},
  // Professional
  'jobs': {'ar': 'الطلبات', 'en': 'Jobs'},
  'jobsSoon': {'ar': 'طلبات العملاء تظهر هنا في السبرنت الرابع.', 'en': 'Customer requests appear here in Sprint 4.'},
  'myProfile': {'ar': 'ملفي', 'en': 'My profile'},
  // Feedback round 1
  'edit': {'ar': 'تعديل', 'en': 'Edit'},
  'delete': {'ar': 'حذف', 'en': 'Delete'},
  'confirmDelete': {'ar': 'سيتم الحذف نهائياً ولا يمكن التراجع.', 'en': 'This is permanent and cannot be undone.'},
  'deleted': {'ar': 'تم الحذف', 'en': 'Deleted'},
  'remove': {'ar': 'إزالة', 'en': 'Remove'},
  'editNursery': {'ar': 'تعديل المشتل', 'en': 'Edit nursery'},
  'editProfessional': {'ar': 'تعديل المختص', 'en': 'Edit professional'},
  'editPriceRange': {'ar': 'تعديل نطاق السعر', 'en': 'Edit price range'},
  'min': {'ar': 'الحد الأدنى (ر.س)', 'en': 'Minimum (SAR)'},
  'max': {'ar': 'الحد الأعلى (ر.س)', 'en': 'Maximum (SAR)'},
  'invalidRange': {'ar': 'الحد الأدنى يجب أن يكون أكبر من صفر وأقل من الأعلى', 'en': 'Minimum must be above zero and below the maximum'},
  'deleteListing': {'ar': 'حذف المنتج', 'en': 'Delete listing'},
  'deletePlant': {'ar': 'حذف النبتة من القائمة', 'en': 'Delete plant from the list'},
  'addNewPlant': {'ar': 'نبتة غير موجودة؟ أضفها', 'en': 'Not in the list? Add a new plant'},
  'newPlant': {'ar': 'نبتة جديدة', 'en': 'New plant'},
  'newPlantNote': {
    'ar': 'النباتات التي تضيفها تظهر بعلامة "أضافها مشتل" لأنها ليست من الدليل الرسمي.',
    'en': 'Plants you add are labelled "added by a nursery" because they are not from the official guide.'
  },
  'scientificName': {'ar': 'الاسم العلمي (اختياري)', 'en': 'Scientific name (optional)'},
  'category': {'ar': 'النوع', 'en': 'Type'},
  'wateringDays': {'ar': 'الري كل (أيام)', 'en': 'Water every (days)'},
  'toxicSwitch': {'ar': 'سامة للأطفال أو الحيوانات', 'en': 'Toxic to children or pets'},
  'descriptionAr': {'ar': 'وصف بالعربية', 'en': 'Description in Arabic'},
  'descriptionEn': {'ar': 'وصف بالإنجليزية', 'en': 'Description in English'},
  'nameOneRequired': {'ar': 'أدخل الاسم بالعربية أو الإنجليزية', 'en': 'Enter the Arabic or English name'},
  'placementRequired': {'ar': 'اختر مكاناً واحداً على الأقل', 'en': 'Choose at least one place'},
  'addedByNursery': {'ar': 'أضافها مشتل — ليست من الدليل الرسمي', 'en': 'Added by a nursery — not from the official guide'},
  'photo': {'ar': 'الصورة', 'en': 'Photo'},
  'addPhoto': {'ar': 'أضف صورة', 'en': 'Add photo'},
  'changePhoto': {'ar': 'غيّر الصورة', 'en': 'Change photo'},
  'removePhoto': {'ar': 'احذف الصورة', 'en': 'Remove photo'},
  'camera': {'ar': 'الكاميرا', 'en': 'Camera'},
  'gallery': {'ar': 'معرض الصور', 'en': 'Gallery'},
  'storageFull': {'ar': 'مساحة التخزين ممتلئة. احذف بعض الصور وحاول مجدداً.', 'en': 'Storage is full. Remove some photos and try again.'},
  'photoCredit': {'ar': 'الصورة: ويكيبيديا', 'en': 'Photo: Wikipedia'},
  'nurseryPhoto': {'ar': 'صورة المشتل', 'en': 'Nursery photo'},
  'typeMaxPrice': {'ar': 'أو اكتب أعلى سعر', 'en': 'Or type a max price'},
  'anyPrice': {'ar': 'أي سعر', 'en': 'Any price'},
  'upTo': {'ar': 'حتى', 'en': 'up to'},
  'coverage': {'ar': 'المدن التي أغطيها', 'en': 'Cities I cover'},
  'myServices': {'ar': 'خدماتي ونطاق أسعارها', 'en': 'My services and their price ranges'},
  'pendingPro': {
    'ar': 'حسابك قيد المراجعة. لن تظهر للعملاء حتى يتم التحقق منك.',
    'en': 'Your account is under review. Customers will not see you until you are verified.'
  },
  'completeRequired': {'ar': 'أكمل الحقول المطلوبة', 'en': 'Complete the required fields'},
  'chooseOne': {'ar': 'اختر واحداً على الأقل', 'en': 'Choose at least one'},
  'editProfile': {'ar': 'تعديل بياناتي', 'en': 'Edit my details'},
  'cityDefaultHint': {'ar': 'تُستخدم مدينتك كتصفية افتراضية في شراء النباتات.', 'en': 'Your city is the default filter in Buy Plants.'},
  'shopPreview': {'ar': 'تتصفح المتجر كمدير. السلة متاحة للعملاء فقط.', 'en': 'You are browsing the shop as admin. The cart is for customers only.'},
  'notFound': {'ar': 'الصفحة غير موجودة', 'en': 'Page not found'},
  'goHome': {'ar': 'الرئيسية', 'en': 'Home'},
};

const Map<String, Map<String, String>> _cities = {
  'riyadh': {'ar': 'الرياض', 'en': 'Riyadh'},
  'jeddah': {'ar': 'جدة', 'en': 'Jeddah'},
  'dammam': {'ar': 'الدمام', 'en': 'Dammam'},
  'makkah': {'ar': 'مكة المكرمة', 'en': 'Makkah'},
  'madinah': {'ar': 'المدينة المنورة', 'en': 'Madinah'},
};

const List<String> cityIds = ['riyadh', 'jeddah', 'dammam', 'makkah', 'madinah'];

const Map<String, Map<String, String>> _enums = {
  'customer': {'ar': 'عميل', 'en': 'Customer'},
  'nursery': {'ar': 'مشتل', 'en': 'Nursery'},
  'professional': {'ar': 'مختص', 'en': 'Professional'},
  'admin': {'ar': 'مدير', 'en': 'Admin'},
  'pending': {'ar': 'قيد المراجعة', 'en': 'Pending'},
  'verified': {'ar': 'موثّق', 'en': 'Verified'},
  'suspended': {'ar': 'موقوف', 'en': 'Suspended'},
  'indoor': {'ar': 'داخل المنزل', 'en': 'Indoor'},
  'outdoor': {'ar': 'خارج المنزل', 'en': 'Outdoor'},
  'full': {'ar': 'شمس كاملة', 'en': 'Full sun'},
  'partial': {'ar': 'شمس جزئية', 'en': 'Part sun'},
  'shade': {'ar': 'ظل', 'en': 'Shade'},
  'low': {'ar': 'قليل', 'en': 'Low'},
  'medium': {'ar': 'متوسط', 'en': 'Medium'},
  'high': {'ar': 'كثير', 'en': 'High'},
  'tree': {'ar': 'شجرة', 'en': 'Tree'},
  'palm': {'ar': 'نخلة', 'en': 'Palm'},
  'shrub': {'ar': 'شجيرة', 'en': 'Shrub'},
  'climber': {'ar': 'متسلقة', 'en': 'Climber'},
  'succulent': {'ar': 'عصارية', 'en': 'Succulent'},
  'groundcover': {'ar': 'غطاء أرضي', 'en': 'Groundcover'},
  'grass': {'ar': 'عشب زينة', 'en': 'Grass'},
  'herb': {'ar': 'عشبة', 'en': 'Herb'},
  'houseplant': {'ar': 'نبات داخلي', 'en': 'Houseplant'},
  'planting': {'ar': 'زراعة', 'en': 'Planting'},
  'pruning': {'ar': 'تقليم', 'en': 'Pruning'},
  'periodicCare': {'ar': 'عناية دورية', 'en': 'Periodic care'},
  'treatment': {'ar': 'علاج', 'en': 'Treatment'},
};

String translate(String lang, String key) => _strings[key]?[lang] ?? key;

/// Text lookups. The language comes from the app's locale, so any widget that
/// shows text rebuilds when the language changes. Safe in callbacks too.
extension Tr on BuildContext {
  String get lang => Localizations.maybeLocaleOf(this)?.languageCode ?? Provider.of<AppState>(this, listen: false).lang;

  String tr(String key) => translate(lang, key);

  String trEnum(Enum value) => _enums[value.name]?[lang] ?? value.name;

  String trCity(String id) => _cities[id]?[lang] ?? id;
}

String roleLabel(String lang, Role role) => _enums[role.name]?[lang] ?? role.name;
