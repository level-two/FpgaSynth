

 
 
 




window new WaveWindow  -name  "Waves for BMG Example Design"
waveform  using  "Waves for BMG Example Design"

      waveform add -signals /ip_bram_1k_tb/status
      waveform add -signals /ip_bram_1k_tb/ip_bram_1k_synth_inst/bmg_port/CLKA
      waveform add -signals /ip_bram_1k_tb/ip_bram_1k_synth_inst/bmg_port/ADDRA
      waveform add -signals /ip_bram_1k_tb/ip_bram_1k_synth_inst/bmg_port/DINA
      waveform add -signals /ip_bram_1k_tb/ip_bram_1k_synth_inst/bmg_port/WEA
      waveform add -signals /ip_bram_1k_tb/ip_bram_1k_synth_inst/bmg_port/ENA
      waveform add -signals /ip_bram_1k_tb/ip_bram_1k_synth_inst/bmg_port/DOUTA

console submit -using simulator -wait no "run"
