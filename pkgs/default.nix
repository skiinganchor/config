{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    iperf3
    jq
    ncdu
    wget
  ];
}
