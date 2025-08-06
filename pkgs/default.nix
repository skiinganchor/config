{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    jq
    ncdu
    wget
  ];
}
