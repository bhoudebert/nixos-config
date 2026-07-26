{ ... }:

{
  networking.hostName = "framework13";
  networking.hosts = {
    "127.0.0.1" = [ 
      "kafka"
      "dms"
      "bff"
      "bringg-adapter"
      "bringg-mock"
      "tdi-mock"
      "pg-dms-by-adeo-fras-d-dms.i.aivencloud.com"
    ];
  };
}
