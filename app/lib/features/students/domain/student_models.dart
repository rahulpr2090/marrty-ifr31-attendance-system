// lib/features/students/domain/student_models.dart
// Dev: rahulpr2000 | RAHUL PR | Marrty LLC

class Student {
  final String  studentId;
  final String  name;
  final String  rollNo;
  final String  pnr;
  final String  batchYear;
  final String  semester;
  final String  gender;
  final String? dob;
  final String? phone;
  final String? email;
  final String  status; // "active" | "inactive" | "passout"
  final String? profileUrl;
  final bool    faceEnrolled;
  final int     enrolledFaces;
  final int     streak;
  final String  createdAt;

  const Student({
    required this.studentId,
    required this.name,
    required this.rollNo,
    required this.pnr,
    required this.batchYear,
    required this.semester,
    required this.gender,
    this.dob,
    this.phone,
    this.email,
    required this.status,
    this.profileUrl,
    required this.faceEnrolled,
    required this.enrolledFaces,
    required this.streak,
    required this.createdAt,
  });

  factory Student.fromJson(Map<String, dynamic> j) => Student(
    studentId:    j['studentId']    as String,
    name:         j['name']         as String,
    rollNo:       j['rollNo']       as String,
    pnr:          j['pnr']          as String,
    batchYear:    j['batchYear']    as String,
    semester:     j['semester']     as String,
    gender:       j['gender']       as String? ?? 'Male',
    dob:          j['dob']          as String?,
    phone:        j['phone']        as String?,
    email:        j['email']        as String?,
    status:       j['status']       as String? ?? 'active',
    profileUrl:   j['profileUrl']   as String?,
    faceEnrolled: (j['faceCount']   as int? ?? 0) > 0,
    enrolledFaces: j['faceCount']   as int? ?? 0,
    streak:       j['streak']       as int? ?? 0,
    createdAt:    j['createdAt']    as String? ?? '',
  );

  Map<String, dynamic> toJson() => {
    'name': name, 'rollNo': rollNo, 'pnr': pnr,
    'batchYear': batchYear, 'semester': semester,
    'gender': gender, 'dob': dob, 'phone': phone, 'email': email,
  };
}

class AttendanceRecord {
  final String  recordId;
  final String  date;
  final String  time;
  final String  sessionType;
  final String  status;
  final String  method;
  final String? emotion;
  final int     streak;

  const AttendanceRecord({
    required this.recordId,
    required this.date,
    required this.time,
    required this.sessionType,
    required this.status,
    required this.method,
    this.emotion,
    required this.streak,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
    recordId:    j['recordId']   as String? ?? '',
    date:        j['date']       as String? ?? '',
    time:        j['time']       as String? ?? '',
    sessionType: j['sessionType']as String? ?? '',
    status:      j['status']     as String? ?? '',
    method:      j['method']     as String? ?? 'auto',
    emotion:     j['emotion']    as String?,
    streak:      j['streak']     as int? ?? 0,
  );
}
