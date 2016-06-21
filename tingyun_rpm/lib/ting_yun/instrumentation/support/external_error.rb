# encoding: utf-8
require 'ting_yun/agent'
require 'ting_yun/support/exception'

module TingYun
  module Instrumentation
    module Support
      module ExternalError




        def capture_exception(response,request,state,type)
          if response.code =~ /^[4,5][0-9][0-9]$/ && response.code!='401'
            e = TingYun::Support::Exception::InternalServerError.new("#{response.code}: #{response.message}")
            klass = "External/#{request.uri.to_s.gsub('/','%2F')}/#{type}"
            e.instance_variable_set(:@tingyun_klass, klass)
            e.instance_variable_set(:@tingyun_external, true)
            e.instance_variable_set(:@tingyun_code, response.code)
            e.instance_variable_set(:@tingyun_trace, caller.reject! { |t| t.include?('tingyun_rpm') })
            TingYun::Agent.notice_error(e)
          end
        end





        ERROR_CODE ={
          :EADDRINFO => 900,
          :ENOTFOUND => 901,
          :EPERM => 1001,
          :ENOENT => 1002,
          :ESRCH => 1003,
          :EINTR => 1004,
          :EIO => 1005,
          :ENXIO => 1006,
          :E2BIG => 1007 ,
          :ENOEXEC => 1008,
          :EBADF => 1009,
          :ECHILD => 1010 ,
          :EAGAIN =>  1011 ,
          :ENOMEM =>  1012 ,
          :EACCES =>  1013 ,
          :EFAULT =>  1014 ,
          :ENOTBLK =>  1015 ,
          :EBUSY =>  1016 ,
          :EEXIST =>  1017 ,
          :EXDEV =>  1018 ,
          :ENODEV =>  1019 ,
          :ENOTDIR =>  1020 ,
          :EISDIR =>  1021 ,
          :EINVAL =>  1022 ,
          :ENFILE =>  1023 ,
          :EMFILE =>  1024 ,
          :ENOTTY =>  1025 ,
          :ETXTBSY =>  1026 ,
          :EFBIG =>  1027 ,
          :ENOSPC =>  1028 ,
          :ESPIPE =>  1029 ,
          :EROFS =>  1030 ,
          :EMLINK =>  1031 ,
          :EPIPE =>  1032 ,
          :EDOM =>  1033 ,
          :ERANGE =>  1034 ,
          :EDEADLK =>  1035 ,
          :ENAMETOOLONG =>  1036 ,
          :ENOLCK =>  1037 ,
          :ENOSYS =>  1038 ,
          :ENOTEMPTY =>  1039 ,
          :ELOOP =>  1040 ,
          :ENOMSG =>  1042 ,
          :EIDRM =>  1043 ,
          :ECHRNG =>  1044 ,
          :EL2NSYNC =>  1045 ,
          :EL3HLT =>  1046 ,
          :EL3RST =>  1047 ,
          :ELNRNG =>  1048 ,
          :EUNATCH =>  1049 ,
          :ENOCSI =>  1050 ,
          :EL2HLT =>  1051 ,
          :EBADE =>  1052 ,
          :EBADR =>  1053 ,
          :EXFULL =>  1054 ,
          :ENOANO =>  1055 ,
          :EBADRQC =>  1056 ,
          :EBADSLT =>  1057 ,
          :EBFONT =>  1059 ,
          :ENOSTR =>  1060 ,
          :ENODATA =>  1061 ,
          :ETIME =>  1062 ,
          :ENOSR =>  1063 ,
          :ENONET =>  1064 ,
          :ENOPKG =>  1065 ,
          :EREMOTE =>  1066 ,
          :ENOLINK =>  1067 ,
          :EADV =>  1068 ,
          :ESRMNT =>  1069 ,
          :ECOMM =>  1070 ,
          :EPROTO =>  1071 ,
          :EMULTIHOP =>  1072 ,
          :EDOTDOT =>  1073 ,
          :EBADMSG =>  1074 ,
          :EOVERFLOW =>  1075 ,
          :ENOTUNIQ =>  1076 ,
          :EBADFD =>  1077 ,
          :EREMCHG =>  1078 ,
          :ELIBACC =>  1079 ,
          :ELIBBAD =>  1080 ,
          :ELIBSCN =>  1081 ,
          :ELIBMAX =>  1082 ,
          :ELIBEXEC =>  1083 ,
          :EILSEQ =>  1084 ,
          :ERESTART =>  1085 ,
          :ESTRPIPE =>  1086 ,
          :EUSERS =>  1087 ,
          :ENOTSOCK =>  1088 ,
          :EDESTADDRREQ =>  1089 ,
          :EMSGSIZE =>  1090 ,
          :EPROTOTYPE =>  1091 ,
          :ENOPROTOOPT =>  1092 ,
          :EPROTONOSUPPORT =>  1093 ,
          :ESOCKTNOSUPPORT =>  1094 ,
          :EOPNOTSUPP =>  1095 ,
          :EPFNOSUPPORT =>  1096 ,
          :EAFNOSUPPORT =>  1097 ,
          :EADDRINUSE =>  1098 ,
          :EADDRNOTAVAIL =>  1099 ,
          :ENETDOWN =>  1100 ,
          :ENETUNREACH =>  1101 ,
          :ENETRESET =>  1102 ,
          :ECONNABORTED =>  1103 ,
          :ECONNRESET =>  1104 ,
          :ENOBUFS =>  1105 ,
          :EISCONN =>  1106 ,
          :ENOTCONN =>  1107 ,
          :ESHUTDOWN =>  1108 ,
          :ETOOMANYREFS =>  1109 ,
          :ETIMEDOUT =>  1110 ,
          :ECONNREFUSED =>  1111 ,
          :EHOSTDOWN =>  1112 ,
          :EHOSTUNREACH =>  1113 ,
          :EALREADY =>  1114 ,
          :EINPROGRESS =>  1115 ,
          :ESTALE =>  1116 ,
          :EUCLEAN =>  1117 ,
          :ENOTNAM =>  1118 ,
          :ENAVAIL =>  1119 ,
          :EISNAM =>  1120 ,
          :EREMOTEIO =>  1121 ,
          :EDQUOT =>  1122 ,
          :ENOMEDIUM =>  1123 ,
          :EMEDIUMTYPE =>  1124 ,
          :ECANCELED =>  1125 ,
          :ENOKEY =>  1126 ,
          :EKEYEXPIRED =>  1127 ,
          :EKEYREVOKED =>  1128 ,
          :EKEYREJECTED =>  1129 ,
          :EOWNERDEAD =>  1130 ,
          :ENOTRECOVERABLE =>  1031
        }
      end
    end
  end
end
