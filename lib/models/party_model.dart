// Model สำหรับปาร์ตี้ (กลุ่มผู้เล่นที่รวมตัวกันไปทำ Party/Community Quest ร่วมกัน)
// ตอนนี้ยังไม่ได้ต่อ backend Party API จริง ใช้ mock data ไปก่อน

class PartyMemberModel {
  final String name;

  PartyMemberModel({required this.name});
}

class PartyModel {
  final PartyMemberModel leader;
  final List<PartyMemberModel> members;

  PartyModel({required this.leader, required this.members});
}

// mock data ไว้ก่อน — TODO: ดึงปาร์ตี้ปัจจุบันของผู้เล่นจาก backend จริงตอนมี endpoint
// เปลี่ยนเป็น null เพื่อจำลองสถานะ "ยังไม่มีปาร์ตี้" (จะเห็น empty state ในหน้า Party)
final PartyModel? mockParty = PartyModel(
  leader: PartyMemberModel(name: 'SuperToru'),
  members: [
    PartyMemberModel(name: 'TofuBoil'),
    PartyMemberModel(name: 'HotOnsen'),
    PartyMemberModel(name: 'BigMatcha'),
    PartyMemberModel(name: 'FreeCola'),
  ],
);
