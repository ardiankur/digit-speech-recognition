s = spectrogram(x)
s = spectrogram(x,window)
s = spectrogram(x,window,noverlap)
s = spectrogram(x,window,noverlap,nfft)
[s,w,t] = spectrogram(___)
[s,f,t] = spectrogram(___,fs)
[s,w,t] = spectrogram(x,window,noverlap,w)
[s,f,t] = spectrogram(x,window,noverlap,f,fs)
[___,ps] = spectrogram(___)
[___] = spectrogram(___,'reassigned')
[___,ps,fc,tc] = spectrogram(___)
[___] = spectrogram(___,freqrange)
[___] = spectrogram(___,Name,Value)
[___] = spectrogram(___,spectrumtype)
spectrogram(___)
spectrogram(___,freqloc)