abstract class IVPNData {
  bool get isVPNEnabled;
  Future<void> enableVPN();
  Future<void> disableVPN();
  Future<void> saveConfig(String jsonContent);
  Future<void> saveProfiles(List<String> profiles);
  Future<void> selectProfile(int index);
  List<String> getProfiles();
  int getSelectedProfileIndex();
  Future<void> clearAll();
}