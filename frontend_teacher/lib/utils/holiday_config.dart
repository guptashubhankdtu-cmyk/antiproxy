import 'package:intl/intl.dart';

/// Public holiday list kept local for now; can be replaced by backend/ICS feed later.
final Set<String> kPublicHolidaysIso = {
  // 2025
  '2025-01-26', // Republic Day (Sunday)
  '2025-02-26', // Mahashivratri
  '2025-03-14', // Holi
  '2025-03-31', // Id-ul-Fitr (Ramzan Eid)
  '2025-04-10', // Mahavir Jayanti
  '2025-04-18', // Good Friday
  '2025-05-12', // Buddha Purnima
  '2025-06-07', // Id-ul-Zuha (Bakri Eid)
  '2025-07-06', // Muharram
  '2025-08-15', // Independence Day
  '2025-08-27', // Ganesh Chaturthi / Vinayak Chaturthi
  '2025-09-05', // Id-e-Milad
  '2025-10-02', // Mahatma Gandhi Birthday / Dussehra (listed same date)
  '2025-10-20', // Diwali (Deepavali)
  '2025-11-05', // Guru Nanak Birthday
  '2025-12-25', // Christmas

  // 2026 (from provided list; includes Gazetted/Restricted key dates)
  '2026-01-01', // New Year's Day
  '2026-01-03', // Hazarat Ali's Birthday
  '2026-01-14', // Pongal / Makar Sankranti
  '2026-01-23', // Vasant Panchami
  '2026-01-26', // Republic Day
  '2026-02-01', // Guru Ravidas Jayanti
  '2026-02-12', // Maharishi Dayanand Saraswati Jayanti
  '2026-02-14', // Valentine’s Day (observance)
  '2026-02-15', // Maha Shivaratri
  '2026-02-17', // Lunar New Year (observance)
  '2026-02-19', // Ramadan Start / Shivaji Jayanti (observance)
  '2026-03-03', // Holika Dahana
  '2026-03-04', // Holi
  '2026-03-19', // Ugadi / Gudi Padwa
  '2026-03-20', // Jamat Ul-Vida / March Equinox
  '2026-03-21', // Ramzan Id (tentative)
  '2026-03-26', // Rama Navami
  '2026-03-31', // Mahavir Jayanti
  '2026-04-02', // Passover / Maundy Thursday
  '2026-04-03', // Good Friday
  '2026-04-05', // Easter Day
  '2026-04-14', // Vaisakhi / Mesadi / Ambedkar Jayanti
  '2026-04-15', // Bahag Bihu
  '2026-05-01', // International Workers' Day / Buddha Purnima
  '2026-05-09', // Birthday of Rabindranath
  '2026-05-10', // Mother's Day (observance)
  '2026-05-27', // Bakrid (tentative)
  '2026-06-21', // Father's Day / June Solstice
  '2026-06-26', // Muharram / Ashura (tentative)
  '2026-07-16', // Rath Yatra
  '2026-08-02', // Friendship Day (observance)
  '2026-08-15', // Independence Day
  '2026-08-26', // Milad un-Nabi (tentative) / Onam
  '2026-08-28', // Raksha Bandhan
  '2026-09-04', // Janmashtami
  '2026-09-14', // Ganesh Chaturthi
  '2026-09-23', // September Equinox
  '2026-10-02', // Mahatma Gandhi Jayanti
  '2026-10-11', // First Day of Sharad Navratri
  '2026-10-17', // First Day of Durga Puja Festivities
  '2026-10-18', // Maha Saptami
  '2026-10-19', // Maha Ashtami
  '2026-10-20', // Dussehra
  '2026-10-26', // Maharishi Valmiki Jayanti
  '2026-10-29', // Karaka Chaturthi
  '2026-10-31', // Halloween (observance)
  '2026-11-08', // Naraka Chaturdasi / Diwali
  '2026-11-09', // Govardhan Puja
  '2026-11-11', // Bhai Duj
  '2026-11-15', // Chhat Puja
  '2026-11-24', // Guru Nanak Jayanti / Guru Tegh Bahadur's Martyrdom Day
  '2026-12-05', // First Day of Hanukkah
  '2026-12-12', // Last day of Hanukkah
  '2026-12-22', // December Solstice
  '2026-12-23', // Hazarat Ali's Birthday
  '2026-12-24', // Christmas Eve
  '2026-12-25', // Christmas
  '2026-12-31', // New Year's Eve
};

bool isPublicHoliday(DateTime date) {
  final key = DateFormat('yyyy-MM-dd').format(date);
  return kPublicHolidaysIso.contains(key);
}

