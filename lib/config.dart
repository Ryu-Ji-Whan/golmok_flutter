/// Supabase 연결 정보.
/// anon key는 앱 안에 들어가도 되는 공개용 키다(데이터는 서버의 행 단위 보안 규칙이 지킨다).
/// service_role 키는 절대 여기에 넣지 않는다.
const supabaseUrl = 'https://iozoocgrtqzscexbxtox.supabase.co';
const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

bool get supabaseConfigured => supabaseAnonKey.isNotEmpty;
