//
//  ViewController.m
//  TextToVideoAndSave
//
//  Created by whn on 2016/12/15.
//  Copyright © 2016年 kk. All rights reserved.
//

#import "ViewController.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface ViewController ()<AVAudioRecorderDelegate>

{
    NSTimer *timer;                  // 设置一个定时器，监控录音时间
    NSURL *playUrl;                  // 读取本地保存的音频
    AVAudioRecorder *recorder;       // 录音器
    AVSpeechSynthesizer *av;         // 文字转语音
}

@property (nonatomic, strong) UIButton *recordBtn;       // 录制按钮
@property (nonatomic, strong) UIButton *playBtn;         // 播放按钮
@property (nonatomic, strong) UIImageView *imageView;    // 音频录制/播放动画显示
@property (nonatomic, strong) AVAudioPlayer *avPlayer;   // 播放本地的短的音效.

@property (nonatomic, strong) UIButton *textBtn;         // 播放文字


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor brownColor];        // 设置背景色
    
    // 配置录音
    [self setAudio];
    
    // 图片
    self.imageView = [[UIImageView alloc] initWithFrame:CGRectMake(130, 80, 107, 128)];
    self.imageView.layer.cornerRadius = 5;
    _imageView.backgroundColor = [UIColor orangeColor];
    _imageView.image = [UIImage imageNamed:@"record_animate_01"];
    [self.view addSubview:self.imageView];
    
    // 录音按钮
    /*
     * 通过点击button的不同方式为录音按钮关联三种不同的事件
     **/
    self.recordBtn = [UIButton buttonWithType:(UIButtonTypeSystem)];
    _recordBtn.frame = CGRectMake(72, 232, 73, 43);
    [_recordBtn setTitle:@"录音" forState:(UIControlStateNormal)];
    [_recordBtn addTarget:self action:@selector(btnDown:) forControlEvents:(UIControlEventTouchDown)];
    [_recordBtn addTarget:self action:@selector(btnUp:) forControlEvents:(UIControlEventTouchUpInside)];
    [_recordBtn addTarget:self action:@selector(btnDragUp:) forControlEvents:(UIControlEventTouchDragExit)];
    [self.view addSubview:self.recordBtn];
    
    // 播放按钮
    self.playBtn = [UIButton buttonWithType:(UIButtonTypeSystem)];
    _playBtn.frame = CGRectMake(214, 232, 73, 43);
    [_playBtn setTitle:@"播放" forState:(UIControlStateNormal)];
    [_playBtn addTarget:self action:@selector(playBtnAction:) forControlEvents:(UIControlEventTouchUpInside)];
    [self.view addSubview:self.playBtn];
    
    // 文字转语音按钮
    self.textBtn = [UIButton buttonWithType:(UIButtonTypeCustom)];
    _textBtn.frame = CGRectMake(143, 300, 73, 43);
    [_textBtn setTitle:@"讲" forState:(UIControlStateNormal)];
    [_textBtn setTitle:@"停" forState:(UIControlStateSelected)];
    [_textBtn addTarget:self action:@selector(textToVideo:) forControlEvents:(UIControlEventTouchUpInside)];
    [self.view addSubview:_textBtn];
}

#pragma mark      -----------  配置录音   ----------
- (void)setAudio
{
    // 录音设置
    NSMutableDictionary *recordSetting = [[NSMutableDictionary alloc] init];
    // 设置录音格式   AVFormatIDKey  == kAudioFormatMPEG4AAC
    [recordSetting setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    // 设置录音采样率   如：AVSampleRateKey == 8000 / 44100 / 96000 （影响音频质量）
    [recordSetting setValue:[NSNumber numberWithFloat:44100] forKey:AVSampleRateKey];
    // 设置通道的数目  1单声道  2立体声
    [recordSetting setValue:[NSNumber numberWithInt:1] forKey:AVNumberOfChannelsKey];
    // 线性采样位数  8， 16， 24， 32 默认是16
    [recordSetting setValue:[NSNumber numberWithInt:16] forKey:AVLinearPCMBitDepthKey];
    // 录音质量
    [recordSetting setValue:[NSNumber numberWithInt:AVAudioQualityHigh] forKey:AVEncoderAudioQualityKey];
    // 将录音放到沙盒中
    NSString *strUrl = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSURL *url = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@luyin.aac", strUrl]];
    playUrl = url;
    
    NSError *error;
    // 初始化Recorder对象
    recorder = [[AVAudioRecorder alloc] initWithURL:url settings:recordSetting error:&error];
    
    // 开启音量检测
    recorder.meteringEnabled = YES;
    recorder.delegate = self;
    
}




#pragma mark      -----------  点击事件   ----------
/**
 * 点击录音按钮不松手时， 录音器开始录音
 */
- (void)btnDown:(UIButton *)sender
{
    if ([recorder prepareToRecord]) {
        [recorder record];
    }
    
    // 设置定时检测， 检测音量大小  实现播放器动画
    timer = [NSTimer scheduledTimerWithTimeInterval:0 target:self selector:@selector(detectionVoice) userInfo:nil repeats:YES];
    
}

/**
 * 录音按钮弹起时， 结束录音
 */
- (void)btnUp:(UIButton *)sender
{
    [recorder stop];
    
    // 关闭定时器
    [timer invalidate];
    
}

/**
 * 当点着button向外拉的时候删除正在录得文件并停止录音 （防止误操作）
 */
 - (void)btnDragUp:(UIButton *)sender
{
    [recorder stop];
    // 删除录制文件
    [recorder deleteRecording];
    [timer invalidate];
}

/**
 * 点击播放按钮的方法实现
 */
- (void)playBtnAction:(UIButton *)sender
{
    [self updateImage];
    
    // 如果播放器正在播放，停止播放并结束此方法
    if (self.avPlayer.playing) {
        [self.avPlayer stop];
        return;
    }
    
    // 播放所录得音频
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:playUrl error:nil];
    self.avPlayer = player;
    [self.avPlayer play];
}


/**
 * 点击播放文字
 */
- (void)textToVideo:(UIButton *)sender
{
    if (sender.selected == NO) {
        if ([av isPaused]) {
            // 如果暂停则恢复， 会从暂停的地方继续
            [av continueSpeaking];
            sender.selected = !sender.selected;
        }else{
            
            // 初始化对象
            av = [[AVSpeechSynthesizer alloc] init];
            
            AVSpeechUtterance *utterance = [[AVSpeechUtterance alloc] initWithString:@"这是一个文字转语音的测试demo"];
            
            // 设置语速，范围0-1，注意0最慢，1最快
//            AVSpeechUtteranceMinimumSpeechRate  最慢
//            AVSpeechUtteranceMaximumSpeechRate  最快
            utterance.rate = 0.5;
            // 设置发音，中文普通话 (File.metal 有支持的语言)
            AVSpeechSynthesisVoice *voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-CN"];
            
            utterance.voice = voice;
            // 开始
            [av speakUtterance:utterance];
            
            sender.selected = !sender.selected;
            
        }
    } else {
        // 暂停
        [av pauseSpeakingAtBoundary:AVSpeechBoundaryWord];
        sender.selected = !sender.selected;
    }
}


#pragma mark -------  播放器动画
- (void)detectionVoice
{
    [recorder updateMeters];  // 刷新音量数据
    
//    [recorder averagePowerForChannel:1.0]   获取音量平均值
//    [recorder peakPowerForChannel:0]        获取音量最大值
    double lowPassResults = pow(10, 0.05*[recorder peakPowerForChannel:0]);
    
    if (0 < lowPassResults <= 0.06) {
        [self.imageView setImage:[UIImage imageNamed:@"record_animate_01"]];
    } else if (0.06 < lowPassResults <= 0.13) {
        [self.imageView setImage:[UIImage imageNamed:@"record_animate_02"]];
    } else if (0.13 < lowPassResults <= 0.20) {
        [self.imageView setImage:[UIImage imageNamed:@"record_animate_03"]];
    } else if (0.20 < lowPassResults <= 0.27) {
        [self.imageView setImage:[UIImage imageNamed:@"record_animate_04"]];
    } else if (0.27 < lowPassResults <= 0.34) {
        [self.imageView setImage:[UIImage imageNamed:@"record_animate_05"]];
    } else if (0.34 < lowPassResults <= 0.41) {
        [self.imageView setImage:[UIImage imageNamed:@"record_animate_06"]];
    } else if (0.41 < lowPassResults <= 0.48) {
        [self.imageView setImage:[UIImage imageNamed:@"record_animate_07"]];
    } else if (0.48 < lowPassResults <= 0.55) {
        [self.imageView setImage:[UIImage imageNamed:@"record_animate_08"]];
    } else if (0.55 < lowPassResults <= 0.62) {
        [self.imageView setImage:[UIImage imageNamed:@"record_animate_09"]];
    } else if (0.62 < lowPassResults <= 0.69) {
        [self.imageView setImage:[UIImage imageNamed:@"record_animate_10"]];
    } else if (0.69 < lowPassResults <= 0.76) {
        [self.imageView setImage:[UIImage imageNamed:@"record_animate_11"]];
    } else if (0.76 < lowPassResults <= 0.83) {
        [self.imageView setImage:[UIImage imageNamed:@"record_animate_12"]];
    } else if (0.83 < lowPassResults <= 0.9) {
        [self.imageView setImage:[UIImage imageNamed:@"record_animate_13"]];
    } else {
        [self.imageView setImage:[UIImage imageNamed:@"record_animate_14"]];
    }
}



// 设置刷新图片
- (void)updateImage
{
    [self.imageView setImage:[UIImage imageNamed:@"record_animate_01"]];
}



- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
