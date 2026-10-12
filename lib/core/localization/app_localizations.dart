import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('en'),
    Locale('si'),
    Locale('ta'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  String text(String english) {
    final translations = switch (locale.languageCode) {
      'si' => _sinhala,
      'ta' => _tamil,
      _ => const <String, String>{},
    };
    return translations[english] ?? english;
  }
}

extension AppLocalizedText on String {
  String localized(BuildContext context) {
    final localizations =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    return localizations?.text(this) ?? this;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
        (supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const _sinhala = <String, String>{
  'Home': 'මුල් පිටුව',
  'Clinic Book': 'සායන පොත',
  'Appointments': 'වේලාවන්',
  'Reports': 'වාර්තා',
  'Profile': 'පැතිකඩ',
  'Patients': 'රෝගීන්',
  'Settings': 'සැකසුම්',
  'Notifications': 'දැනුම්දීම්',
  'Language': 'භාෂාව',
  'Dark Mode': 'අඳුරු මාදිලිය',
  'In-app notifications': 'යෙදුම තුළ දැනුම්දීම්',
  'Notifications are turned off in Settings.':
      'සැකසුම් තුළ දැනුම්දීම් අක්‍රිය කර ඇත.',
  'Privacy': 'පෞද්ගලිකත්වය',
  'Terms & Conditions': 'නියම සහ කොන්දේසි',
  'Logout': 'ඉවත් වන්න',
  'Close': 'වසන්න',
  'English': 'ඉංග්‍රීසි',
  'No notifications.': 'දැනුම්දීම් නැත.',
  'No appointments yet.': 'තවම වේලාවන් නොමැත.',
  'Upcoming': 'ඉදිරි වේලාවන්',
  'Previous': 'පෙර වේලාවන්',
  'Today': 'අද',
  'Completed': 'සම්පූර්ණයි',
  'Cancelled': 'අවලංගුයි',
  'Search Patients': 'රෝගීන් සොයන්න',
  'Patient ID, NIC, name or phone': 'රෝගී අංකය, හැඳුනුම්පත, නම හෝ දුරකථනය',
  'No patients match your search.': 'ඔබගේ සෙවුමට රෝගීන් හමු නොවීය.',
  'No patients are assigned to or have booked with your account yet.':
      'ඔබගේ ගිණුමට රෝගීන් පවරා හෝ ඔබ සමඟ වේලාවක් වෙන්කර නොමැත.',
  'Welcome back': 'නැවත සාදරයෙන් පිළිගනිමු',
  'Sign in to your E-Clinic Book': 'E-Clinic Book වෙත පිවිසෙන්න',
  'Email': 'විද්‍යුත් තැපෑල',
  'Password': 'මුරපදය',
  'Forgot Password?': 'මුරපදය අමතකද?',
  'Login': 'පිවිසෙන්න',
  'Create Account': 'ගිණුමක් සාදන්න',
  'Report Details': 'වාර්තා විස්තර',
  'Report file': 'වාර්තා ගොනුව',
  'Type': 'වර්ගය',
  'Lab': 'රසායනාගාරය',
  'Date': 'දිනය',
  'Status': 'තත්ත්වය',
  'Patient': 'රෝගියා',
  'Patient ID': 'රෝගී අංකය',
  'Doctor ID': 'වෛද්‍ය අංකය',
  'Uploaded document': 'උඩුගත කළ ලේඛනය',
  'Report preview': 'වාර්තා පෙරදසුන',
  'View / Download Report': 'වාර්තාව බලන්න / බාගන්න',
  'Visit not found.': 'සායන වාර්තාව හමු නොවීය.',
  'Report not found.': 'වාර්තාව හමු නොවීය.',
  'Privacy information': 'පෞද්ගලිකත්ව තොරතුරු',
  'Terms of use': 'භාවිත නියම',
  'About E-Clinic Book': 'E-Clinic Book ගැන',
  'Privacy Policy': 'පෞද්ගලිකත්ව ප්‍රතිපත්තිය',
  'Your medical records are visible only to you and doctors you share your QR code with.':
      'ඔබගේ වෛද්‍ය වාර්තා ඔබට සහ ඔබගේ QR කේතය බෙදාගත් වෛද්‍යවරුන්ට පමණක් දැකිය හැක.',
  'By using E-Clinic Book you agree to keep your login details private and use the app for personal healthcare management.':
      'E-Clinic Book භාවිතයෙන් ඔබ පිවිසුම් තොරතුරු රහසිගතව තබාගෙන පුද්ගලික සෞඛ්‍ය කළමනාකරණය සඳහා යෙදුම භාවිතා කිරීමට එකඟ වේ.',
  'Your Digital Clinic Book.': 'ඔබගේ ඩිජිටල් සායන පොත.',
  'Your health information': 'ඔබගේ සෞඛ්‍ය තොරතුරු',
  'Who can view your records': 'ඔබගේ වාර්තා බැලිය හැක්කේ කාටද',
  'Uploaded report files': 'උඩුගත කළ වාර්තා ගොනු',
  'Your choices': 'ඔබගේ තේරීම්',
  'Purpose of the app': 'යෙදුමේ අරමුණ',
  'Your account': 'ඔබගේ ගිණුම',
  'Appointments and records': 'වේලාවන් සහ වාර්තා',
  'Safe use': 'ආරක්ෂිත භාවිතය',
  'What you can do': 'ඔබට කළ හැකි දේ',
  'Version 1.0.0': 'අනුවාදය 1.0.0',
  'Hospital': 'රෝහල',
  'Clinic': 'සායනය',
  'Doctor': 'වෛද්‍යවරයා',
  'Diagnosis': 'රෝග නිර්ණය',
  'Treatment': 'ප්‍රතිකාර',
  'Prescription': 'බෙහෙත් වට්ටෝරුව',
  'Symptoms': 'රෝග ලක්ෂණ',
  'Vital Signs': 'ජීව ලක්ෂණ',
  'Next Appointment': 'ඊළඟ හමුවීම',
  'Doctor Notes': 'වෛද්‍ය සටහන්',
  'Blood pressure': 'රුධිර පීඩනය',
  'Heart rate': 'හෘද ස්පන්දන වේගය',
  'Temperature': 'උෂ්ණත්වය',
  'Weight': 'බර',
  'Height': 'උස',
  'No medicines prescribed': 'ඖෂධ නියම කර නැත',
  'Not scheduled': 'සැලසුම් කර නැත',
  'View Patient': 'රෝගියා බලන්න',
  'Nothing here': 'මෙහි කිසිවක් නැත',
  'No upcoming appointments': 'ඉදිරි හමුවීම් නැත',
  'No previous appointments': 'පෙර හමුවීම් නැත',
  'Today\'s Appointments': 'අද හමුවීම්',
  'Total Patients': 'මුළු රෝගීන්',
  'Pending Visits': 'අපේක්ෂිත හමුවීම්',
  'Completed Visits': 'සම්පූර්ණ කළ හමුවීම්',
  'No appointments today': 'අද හමුවීම් නැත',
  'Appointment Details': 'හමුවීමේ විස්තර',
  'Mark as Completed': 'සම්පූර්ණ කළ ලෙස සලකුණු කරන්න',
  'Cancel Appointment': 'හමුවීම අවලංගු කරන්න',
  'Appointment cancelled': 'හමුවීම අවලංගු කරන ලදී',
  'Digital Clinic Book': 'ඩිජිටල් සායන පොත',
  'Patient Information': 'රෝගියාගේ තොරතුරු',
  'Clinic Visits': 'සායන හමුවීම්',
  'No clinic visits yet.': 'තවම සායන හමුවීම් නැත.',
  'Laboratory Reports': 'රසායනාගාර වාර්තා',
  'No laboratory reports yet.': 'තවම රසායනාගාර වාර්තා නැත.',
  'No prescriptions found.': 'බෙහෙත් වට්ටෝරු හමු නොවීය.',
  'Book Appointment': 'හමුවීමක් වෙන්කරන්න',
  'Confirm Booking': 'වෙන්කිරීම තහවුරු කරන්න',
  'Select a doctor': 'වෛද්‍යවරයෙකු තෝරන්න',
  'Select a clinic': 'සායනයක් තෝරන්න',
  'Select a time': 'වේලාවක් තෝරන්න',
  'Appointment booked': 'හමුවීම වෙන් කරන ලදී',
  'Previous appointments': 'පෙර හමුවීම්',
  'Upcoming appointments': 'ඉදිරි හමුවීම්',
  'Retry': 'නැවත උත්සාහ කරන්න',
  'Welcome back,': 'නැවත සාදරයෙන් පිළිගනිමු,',
  'Prescriptions': 'බෙහෙත් වට්ටෝරු',
  'Cancel appointment?': 'හමුවීම අවලංගු කරන්නද?',
  'Keep': 'තබාගන්න',
  'Cancel it': 'අවලංගු කරන්න',
  'No visits recorded yet': 'තවම හමුවීම් සටහන් කර නැත',
  'No active prescriptions': 'සක්‍රිය බෙහෙත් වට්ටෝරු නැත',
  'My QR Code': 'මගේ QR කේතය',
  'Show this code to your doctor': 'මෙම කේතය ඔබගේ වෛද්‍යවරයාට පෙන්වන්න',
  'Change Password': 'මුරපදය වෙනස් කරන්න',
  'Edit Profile': 'පැතිකඩ සංස්කරණය කරන්න',
  'Save': 'සුරකින්න',
  'Update': 'යාවත්කාලීන කරන්න',
  'Name': 'නම',
  'NIC': 'ජාතික හැඳුනුම්පත් අංකය',
  'Date of Birth': 'උපන් දිනය',
  'Gender': 'ස්ත්‍රී පුරුෂ භාවය',
  'Phone': 'දුරකථනය',
  'Phone Number': 'දුරකථන අංකය',
  'Address': 'ලිපිනය',
  'Full Name': 'සම්පූර්ණ නම',
  'Save Patient Profile': 'රෝගී පැතිකඩ සුරකින්න',
  'Complete your patient profile': 'ඔබගේ රෝගී පැතිකඩ සම්පූර්ණ කරන්න',
  'No doctors are currently available for booking. Please contact the clinic.':
      'දැනට වෙන්කිරීම සඳහා වෛද්‍යවරුන් නොමැත. සායනය අමතන්න.',
  'General Clinic': 'සාමාන්‍ය සායනය',
  'Morning Clinic': 'උදෑසන සායනය',
  'No patient profile found.': 'රෝගී පැතිකඩක් හමු නොවීය.',
  'E-Clinic Book could not start': 'E-Clinic Book ආරම්භ කිරීමට නොහැකි විය',
  'Your patient profile, appointments, clinic visits and reports are stored to provide the app services. Keep your sign-in details private and use Logout on shared devices.':
      'යෙදුම් සේවා සැපයීම සඳහා ඔබගේ රෝගී පැතිකඩ, හමුවීම්, සායන විස්තර සහ වාර්තා ගබඩා කරනු ලැබේ. පිවිසුම් තොරතුරු රහසිගතව තබාගෙන බෙදාගත් උපාංගවලින් ඉවත් වන්න.',
  'Doctors can view your profile details when you book with them. Clinic visit history and reports are available only to your assigned primary doctor.':
      'ඔබ වෛද්‍යවරයෙකු සමඟ වේලාවක් වෙන් කළ විට ඔහුට ඔබගේ පැතිකඩ විස්තර දැකිය හැක. සායන ඉතිහාසය සහ වාර්තා බැලිය හැක්කේ ඔබට පවරා ඇති ප්‍රධාන වෛද්‍යවරයාට පමණි.',
  'Report details are stored in the clinic system and uploaded files are kept in private cloud storage. Do not upload documents that are unrelated to your care.':
      'වාර්තා විස්තර සායන පද්ධතියේ ගබඩා කරන අතර උඩුගත කළ ගොනු පුද්ගලික වලාකුළු ගබඩාවේ තබා ඇත. ඔබගේ ප්‍රතිකාරයට අදාළ නොවන ලේඛන උඩුගත නොකරන්න.',
  'Contact your clinic to ask about correcting account details or your records. The Notifications setting controls in-app notification visibility on this device.':
      'ගිණුම් තොරතුරු හෝ වාර්තා නිවැරදි කිරීම සඳහා සායනය අමතන්න. දැනුම්දීම් සැකසුම මෙම උපාංගයේ යෙදුම්-තුළ දැනුම්දීම් පෙන්වීම පාලනය කරයි.',
  'E-Clinic Book helps patients and clinics organize appointments, clinic visit details and laboratory reports. It is not an emergency service and does not replace professional medical advice, diagnosis or treatment.':
      'E-Clinic Book මගින් රෝගීන්ට සහ සායනවලට හමුවීම්, සායනික තොරතුරු සහ රසායනාගාර වාර්තා සංවිධානය කළ හැක. මෙය හදිසි සේවාවක් නොවන අතර වෘත්තීය වෛද්‍ය උපදෙස්, රෝග නිර්ණය හෝ ප්‍රතිකාර වෙනුවට භාවිතා නොකළ යුතුය.',
  'Provide accurate information, protect your password and log out when using a shared device. Tell your clinic if you suspect someone else has used your account.':
      'නිවැරදි තොරතුරු ලබාදී, මුරපදය ආරක්ෂා කර, බෙදාගත් උපාංගයකින් භාවිතයෙන් පසු ඉවත් වන්න. වෙනත් අයෙකු ඔබගේ ගිණුම භාවිතා කළ බව සැක නම් සායනයට දන්වන්න.',
  'Check appointment details with the clinic. A booking request does not guarantee availability until confirmed by the clinic. Keep copies of important medical documents.':
      'හමුවීමේ විස්තර සායනය සමඟ තහවුරු කරන්න. සායනය තහවුරු කරන තුරු වෙන්කිරීම ලබාගත හැකි බව සහතික නොවේ. වැදගත් වෛද්‍ය ලේඛනවල පිටපත් තබාගන්න.',
  'Do not use the app to report an emergency. Contact local emergency services or seek immediate medical care.':
      'හදිසි අවස්ථා දැනුම් දීමට මෙම යෙදුම භාවිතා නොකරන්න. ප්‍රාදේශීය හදිසි සේවාවන් අමතන්න හෝ වහාම වෛද්‍ය ප්‍රතිකාර ලබාගන්න.',
  'Your Digital Clinic Book.\nVersion 1.0.0':
      'ඔබගේ ඩිජිටල් සායන පොත.\nඅනුවාදය 1.0.0',
  'Manage appointments, review clinic visit information and access laboratory reports shared with your account.':
      'හමුවීම් කළමනාකරණය කරන්න, සායන විස්තර සමාලෝචනය කරන්න සහ ඔබගේ ගිණුම සමඟ බෙදාගත් රසායනාගාර වාර්තා බලන්න.',
};

const _tamil = <String, String>{
  'Home': 'முகப்பு',
  'Clinic Book': 'மருத்துவப் புத்தகம்',
  'Appointments': 'சந்திப்புகள்',
  'Reports': 'அறிக்கைகள்',
  'Profile': 'சுயவிவரம்',
  'Patients': 'நோயாளிகள்',
  'Settings': 'அமைப்புகள்',
  'Notifications': 'அறிவிப்புகள்',
  'Language': 'மொழி',
  'Dark Mode': 'இருண்ட பயன்முறை',
  'In-app notifications': 'செயலிக்குள் அறிவிப்புகள்',
  'Notifications are turned off in Settings.':
      'அமைப்புகளில் அறிவிப்புகள் முடக்கப்பட்டுள்ளன.',
  'Privacy': 'தனியுரிமை',
  'Terms & Conditions': 'விதிமுறைகள் மற்றும் நிபந்தனைகள்',
  'About E-Clinic Book': 'E-Clinic Book பற்றி',
  'Logout': 'வெளியேறு',
  'Close': 'மூடு',
  'English': 'ஆங்கிலம்',
  'No notifications.': 'அறிவிப்புகள் இல்லை.',
  'No appointments yet.': 'சந்திப்புகள் எதுவும் இல்லை.',
  'Upcoming': 'வரவிருக்கும்',
  'Previous': 'முந்தைய',
  'Today': 'இன்று',
  'Completed': 'முடிந்தது',
  'Cancelled': 'ரத்து செய்யப்பட்டது',
  'Search Patients': 'நோயாளிகளைத் தேடுங்கள்',
  'Patient ID, NIC, name or phone':
      'நோயாளர் எண், அடையாள எண், பெயர் அல்லது தொலைபேசி',
  'No patients match your search.': 'உங்கள் தேடலுக்கு நோயாளிகள் இல்லை.',
  'No patients are assigned to or have booked with your account yet.':
      'உங்கள் கணக்கிற்கு நோயாளிகள் ஒதுக்கப்படவோ உங்களுடன் சந்திப்பை முன்பதிவு செய்யவோ இல்லை.',
  'Welcome back': 'மீண்டும் வருக',
  'Sign in to your E-Clinic Book': 'E-Clinic Book-இல் உள்நுழைக',
  'Email': 'மின்னஞ்சல்',
  'Password': 'கடவுச்சொல்',
  'Forgot Password?': 'கடவுச்சொல் மறந்துவிட்டதா?',
  'Login': 'உள்நுழைக',
  'Create Account': 'கணக்கை உருவாக்கு',
  'Report Details': 'அறிக்கை விவரங்கள்',
  'Report file': 'அறிக்கை கோப்பு',
  'Type': 'வகை',
  'Lab': 'ஆய்வகம்',
  'Date': 'தேதி',
  'Status': 'நிலை',
  'Patient': 'நோயாளர்',
  'Patient ID': 'நோயாளர் எண்',
  'Doctor ID': 'மருத்துவர் எண்',
  'Uploaded document': 'பதிவேற்றிய ஆவணம்',
  'Report preview': 'அறிக்கை முன்னோட்டம்',
  'View / Download Report': 'அறிக்கையைப் பார்க்க / பதிவிறக்க',
  'Visit not found.': 'வருகை காணப்படவில்லை.',
  'Report not found.': 'அறிக்கை காணப்படவில்லை.',
  'Privacy information': 'தனியுரிமை தகவல்',
  'Terms of use': 'பயன்பாட்டு விதிமுறைகள்',
  'Privacy Policy': 'தனியுரிமைக் கொள்கை',
  'Your medical records are visible only to you and doctors you share your QR code with.':
      'உங்கள் மருத்துவப் பதிவுகளை நீங்கள் மற்றும் உங்கள் QR குறியீட்டைப் பகிர்ந்த மருத்துவர்கள் மட்டுமே பார்க்க முடியும்.',
  'By using E-Clinic Book you agree to keep your login details private and use the app for personal healthcare management.':
      'E-Clinic Book-ஐப் பயன்படுத்துவதன் மூலம், உள்நுழைவு விவரங்களை ரகசியமாக வைத்திருந்து தனிப்பட்ட சுகாதார நிர்வாகத்திற்காக செயலியைப் பயன்படுத்த ஒப்புக்கொள்கிறீர்கள்.',
  'Your Digital Clinic Book.': 'உங்கள் டிஜிட்டல் மருத்துவப் புத்தகம்.',
  'Your health information': 'உங்கள் சுகாதாரத் தகவல்',
  'Who can view your records': 'உங்கள் பதிவுகளை யார் பார்க்கலாம்',
  'Uploaded report files': 'பதிவேற்றிய அறிக்கை கோப்புகள்',
  'Your choices': 'உங்கள் விருப்பங்கள்',
  'Purpose of the app': 'செயலியின் நோக்கம்',
  'Your account': 'உங்கள் கணக்கு',
  'Appointments and records': 'சந்திப்புகள் மற்றும் பதிவுகள்',
  'Safe use': 'பாதுகாப்பான பயன்பாடு',
  'What you can do': 'நீங்கள் செய்யக்கூடியவை',
  'Version 1.0.0': 'பதிப்பு 1.0.0',
  'Hospital': 'மருத்துவமனை',
  'Clinic': 'மருத்துவமனைப் பிரிவு',
  'Doctor': 'மருத்துவர்',
  'Diagnosis': 'நோயறிதல்',
  'Treatment': 'சிகிச்சை',
  'Prescription': 'மருந்துச் சீட்டு',
  'Symptoms': 'அறிகுறிகள்',
  'Vital Signs': 'முக்கிய அறிகுறிகள்',
  'Next Appointment': 'அடுத்த சந்திப்பு',
  'Doctor Notes': 'மருத்துவர் குறிப்புகள்',
  'Blood pressure': 'இரத்த அழுத்தம்',
  'Heart rate': 'இதயத் துடிப்பு',
  'Temperature': 'வெப்பநிலை',
  'Weight': 'எடை',
  'Height': 'உயரம்',
  'No medicines prescribed': 'மருந்துகள் பரிந்துரைக்கப்படவில்லை',
  'Not scheduled': 'திட்டமிடப்படவில்லை',
  'View Patient': 'நோயாளியைப் பார்க்க',
  'Nothing here': 'இங்கு எதுவும் இல்லை',
  'No upcoming appointments': 'வரவிருக்கும் சந்திப்புகள் இல்லை',
  'No previous appointments': 'முந்தைய சந்திப்புகள் இல்லை',
  'Today\'s Appointments': 'இன்றைய சந்திப்புகள்',
  'Total Patients': 'மொத்த நோயாளிகள்',
  'Pending Visits': 'நிலுவையிலுள்ள வருகைகள்',
  'Completed Visits': 'முடிக்கப்பட்ட வருகைகள்',
  'No appointments today': 'இன்று சந்திப்புகள் இல்லை',
  'Appointment Details': 'சந்திப்பு விவரங்கள்',
  'Mark as Completed': 'முடிந்ததாகக் குறிக்கவும்',
  'Cancel Appointment': 'சந்திப்பை ரத்து செய்',
  'Appointment cancelled': 'சந்திப்பு ரத்து செய்யப்பட்டது',
  'Digital Clinic Book': 'டிஜிட்டல் மருத்துவப் புத்தகம்',
  'Patient Information': 'நோயாளர் தகவல்',
  'Clinic Visits': 'மருத்துவ வருகைகள்',
  'No clinic visits yet.': 'மருத்துவ வருகைகள் இன்னும் இல்லை.',
  'Laboratory Reports': 'ஆய்வக அறிக்கைகள்',
  'No laboratory reports yet.': 'ஆய்வக அறிக்கைகள் இன்னும் இல்லை.',
  'No prescriptions found.': 'மருந்துச் சீட்டுகள் எதுவும் இல்லை.',
  'Book Appointment': 'சந்திப்பை பதிவு செய்',
  'Confirm Booking': 'பதிவை உறுதிப்படுத்து',
  'Select a doctor': 'மருத்துவரைத் தேர்ந்தெடுக்கவும்',
  'Select a clinic': 'மருத்துவப் பிரிவைத் தேர்ந்தெடுக்கவும்',
  'Select a time': 'நேரத்தைத் தேர்ந்தெடுக்கவும்',
  'Appointment booked': 'சந்திப்பு பதிவு செய்யப்பட்டது',
  'Retry': 'மீண்டும் முயற்சிக்கவும்',
  'Welcome back,': 'மீண்டும் வருக,',
  'Prescriptions': 'மருந்துச் சீட்டுகள்',
  'Cancel appointment?': 'சந்திப்பை ரத்து செய்யவா?',
  'Keep': 'வைத்திரு',
  'Cancel it': 'ரத்து செய்',
  'No visits recorded yet': 'வருகைகள் இன்னும் பதிவு செய்யப்படவில்லை',
  'No active prescriptions': 'செயலில் உள்ள மருந்துச் சீட்டுகள் இல்லை',
  'My QR Code': 'எனது QR குறியீடு',
  'Show this code to your doctor':
      'இந்தக் குறியீட்டை உங்கள் மருத்துவரிடம் காட்டுங்கள்',
  'Change Password': 'கடவுச்சொல்லை மாற்று',
  'Edit Profile': 'சுயவிவரத்தைத் திருத்து',
  'Save': 'சேமி',
  'Update': 'புதுப்பி',
  'Name': 'பெயர்',
  'NIC': 'அடையாள அட்டை எண்',
  'Date of Birth': 'பிறந்த தேதி',
  'Gender': 'பாலினம்',
  'Phone': 'தொலைபேசி',
  'Phone Number': 'தொலைபேசி எண்',
  'Address': 'முகவரி',
  'Full Name': 'முழுப் பெயர்',
  'Save Patient Profile': 'நோயாளர் சுயவிவரத்தைச் சேமி',
  'Complete your patient profile':
      'உங்கள் நோயாளர் சுயவிவரத்தை நிறைவு செய்யுங்கள்',
  'No doctors are currently available for booking. Please contact the clinic.':
      'தற்போது முன்பதிவுக்கு மருத்துவர்கள் இல்லை. மருத்துவமனையைத் தொடர்புகொள்ளுங்கள்.',
  'General Clinic': 'பொது மருத்துவப் பிரிவு',
  'Morning Clinic': 'காலை மருத்துவப் பிரிவு',
  'E-Clinic Book could not start': 'E-Clinic Book-ஐத் தொடங்க முடியவில்லை',
  'Your patient profile, appointments, clinic visits and reports are stored to provide the app services. Keep your sign-in details private and use Logout on shared devices.':
      'செயலி சேவைகளை வழங்க உங்கள் நோயாளர் சுயவிவரம், சந்திப்புகள், மருத்துவ வருகைகள் மற்றும் அறிக்கைகள் சேமிக்கப்படுகின்றன. உள்நுழைவு விவரங்களை ரகசியமாக வைத்திருந்து பகிரப்பட்ட சாதனங்களில் வெளியேறவும்.',
  'Doctors can view your profile details when you book with them. Clinic visit history and reports are available only to your assigned primary doctor.':
      'நீங்கள் மருத்துவரிடம் சந்திப்பை முன்பதிவு செய்தால், அவர் உங்கள் சுயவிவர விவரங்களைக் காணலாம். மருத்துவ வருகை வரலாறும் அறிக்கைகளும் உங்களுக்கு ஒதுக்கப்பட்ட முதன்மை மருத்துவருக்கு மட்டுமே கிடைக்கும்.',
  'Report details are stored in the clinic system and uploaded files are kept in private cloud storage. Do not upload documents that are unrelated to your care.':
      'அறிக்கை விவரங்கள் மருத்துவமனை அமைப்பில் சேமிக்கப்படுகின்றன; பதிவேற்றிய கோப்புகள் தனிப்பட்ட மேக சேமிப்பில் வைக்கப்படுகின்றன. உங்கள் சிகிச்சைக்கு தொடர்பில்லாத ஆவணங்களைப் பதிவேற்ற வேண்டாம்.',
  'Contact your clinic to ask about correcting account details or your records. The Notifications setting controls in-app notification visibility on this device.':
      'கணக்கு விவரங்கள் அல்லது பதிவுகளைத் திருத்த மருத்துவமனையைத் தொடர்புகொள்ளுங்கள். அறிவிப்பு அமைப்பு இந்தச் சாதனத்தில் செயலிக்குள் அறிவிப்புகளைக் காட்டுவதை கட்டுப்படுத்துகிறது.',
  'E-Clinic Book helps patients and clinics organize appointments, clinic visit details and laboratory reports. It is not an emergency service and does not replace professional medical advice, diagnosis or treatment.':
      'E-Clinic Book நோயாளிகளுக்கும் மருத்துவமனைகளுக்கும் சந்திப்புகள், மருத்துவ வருகை விவரங்கள் மற்றும் ஆய்வக அறிக்கைகளை ஒழுங்குபடுத்த உதவுகிறது. இது அவசர சேவை அல்ல; மருத்துவ ஆலோசனை, நோயறிதல் அல்லது சிகிச்சைக்கு மாற்றாகாது.',
  'Provide accurate information, protect your password and log out when using a shared device. Tell your clinic if you suspect someone else has used your account.':
      'சரியான தகவல்களை வழங்கி, கடவுச்சொல்லைப் பாதுகாத்து, பகிரப்பட்ட சாதனத்தைப் பயன்படுத்திய பிறகு வெளியேறவும். வேறு யாராவது உங்கள் கணக்கைப் பயன்படுத்தியதாகச் சந்தேகித்தால் மருத்துவமனைக்குத் தெரிவிக்கவும்.',
  'Check appointment details with the clinic. A booking request does not guarantee availability until confirmed by the clinic. Keep copies of important medical documents.':
      'சந்திப்பு விவரங்களை மருத்துவமனையுடன் சரிபார்க்கவும். மருத்துவமனை உறுதிப்படுத்தும் வரை முன்பதிவு கிடைக்கும் என உத்தரவாதமில்லை. முக்கியமான மருத்துவ ஆவணங்களின் நகல்களை வைத்திருங்கள்.',
  'Do not use the app to report an emergency. Contact local emergency services or seek immediate medical care.':
      'அவசரநிலையைப் புகாரளிக்க இந்தச் செயலியைப் பயன்படுத்த வேண்டாம். உள்ளூர் அவசர சேவைகளைத் தொடர்புகொள்ளுங்கள் அல்லது உடனடியாக மருத்துவ உதவியை நாடுங்கள்.',
  'Your Digital Clinic Book.\nVersion 1.0.0':
      'உங்கள் டிஜிட்டல் மருத்துவப் புத்தகம்.\nபதிப்பு 1.0.0',
  'Manage appointments, review clinic visit information and access laboratory reports shared with your account.':
      'சந்திப்புகளை நிர்வகித்து, மருத்துவ வருகை விவரங்களைப் பார்வையிட்டு, உங்கள் கணக்குடன் பகிரப்பட்ட ஆய்வக அறிக்கைகளை அணுகுங்கள்.',
};
