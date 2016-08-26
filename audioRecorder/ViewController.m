//
//  ViewController.m
//  audioRecorder
//
//  Created by QianFan_Ryan on 16/8/25.
//  Copyright © 2016年 QianFan. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()<AVAudioRecorderDelegate>

@property (nonatomic,strong) AVAudioRecorder *audioRecorder;//音频录音机
@property (nonatomic,strong) AVAudioPlayer *audioPlayer;//音频播放器，用于播放录音文件
@property (nonatomic,weak) NSTimer *timer;//显示录音
@property (nonatomic,strong) NSString *outputFile;
@property (nonatomic,weak) IBOutlet UIProgressView *audioPower;


@end

@implementation ViewController

- (void)dealloc{
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)setAudioSessionToRecord{
    //设置为录音状态
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:nil];
}

- (void)setAudioSessionToPlay{
    //切换成播放音频状态，PlayAndRecord状态下无法通过扬声器播放，只能使用耳机播放
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
}

- (void)audioPowerChange{
    [self.audioRecorder updateMeters];//更新测量值
    float power= [self.audioRecorder averagePowerForChannel:0];//取得第一个通道的音频，注意音频强度范围时-160到0
    CGFloat progress=(1.0/160.0)*(power+160.0);
    [self.audioPower setProgress:progress];
}

#pragma mark -- property
- (AVAudioRecorder *)audioRecorder{
    if (!_audioRecorder) {
        //创建录音文件保存路径
        _outputFile = [self outputFilePath];
        NSURL *url = [NSURL fileURLWithPath:_outputFile];
        //创建录音格式设置
        NSDictionary *setting = [self getAudioSetting];
        //创建录音机
        NSError *error = nil;
        _audioRecorder = [[AVAudioRecorder alloc]initWithURL:url settings:setting error:&error];
        _audioRecorder.delegate = self;
        _audioRecorder.meteringEnabled = YES;//如果要监控声波则必须设置为YES
        if (error) {
            NSLog(@"创建录音机对象时发生错误，错误信息：%@",error.localizedDescription);
            return nil;
        }
    }
    return _audioRecorder;
}

-(NSTimer *)timer{
    if (!_timer) {
        [[NSRunLoop currentRunLoop]addTimer:(_timer = [NSTimer timerWithTimeInterval:.1f target:self selector:@selector(audioPowerChange) userInfo:nil repeats:YES]) forMode:NSRunLoopCommonModes];
    }
    return _timer;
}

#pragma mark -- AVAudioRecorderDelegate
-(void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag{
    if (![self.audioPlayer isPlaying]) {
        [self.audioPlayer play];
    }
    NSLog(@"录音完成!");
}

#pragma mark -- action
- (IBAction)recordButtonTouchDown:(UIButton *)sender {
    NSLog(@"recordButtonTouchDown");
    if (![self checkAuthorization]) {
        return;
    }
    [self setAudioSessionToRecord];
    if (![self.audioRecorder isRecording]) {
        [self.audioRecorder record];
        self.timer.fireDate = [NSDate distantPast];
    }
}

- (IBAction)recordButtonTouchEnd:(UIButton *)sender {
    NSLog(@"recordButtonTouchEnd");
    [self.audioRecorder stop];
    self.timer.fireDate = [NSDate distantFuture];
    self.audioPower.progress=0.0;
}

- (IBAction)recordButtonTouchCancel:(UIButton *)sender {
    NSLog(@"recordButtonTouchCancel");
    [self.audioRecorder stop];
    self.timer.fireDate = [NSDate distantFuture];
    self.audioPower.progress=0.0;
}

- (IBAction)playButtonClicked:(UIButton *)sender {
    NSLog(@"playButtonClicked");
    if (_audioPlayer && _audioPlayer.isPlaying) {
        return;
    }
    if (_outputFile && [[NSFileManager defaultManager]fileExistsAtPath:_outputFile]) {
        [self setAudioSessionToPlay];
        NSURL *fileURL = [NSURL fileURLWithPath:_outputFile];
        NSError *error = nil;
        _audioPlayer = [[AVAudioPlayer alloc]initWithContentsOfURL:fileURL error:&error];
        _audioPlayer.numberOfLoops = 0;
        [_audioPlayer prepareToPlay];
        [_audioPlayer play];
    }
}

#pragma mark -- help
- (NSDictionary *)getAudioSetting{
    NSMutableDictionary *dicM = [NSMutableDictionary dictionary];
    //设置录音格式
    [dicM setObject:@(kAudioFormatLinearPCM) forKey:AVFormatIDKey];
    //设置录音采样率，8000是电话采样率，对于一般录音已经够了
    [dicM setObject:@(8000) forKey:AVSampleRateKey];
    //设置通道,这里采用单声道
    [dicM setObject:@(1) forKey:AVNumberOfChannelsKey];
    //每个采样点位数,分为8、16、24、32
    [dicM setObject:@(16) forKey:AVLinearPCMBitDepthKey];
    //是否使用浮点数采样
    [dicM setObject:@(NO) forKey:AVLinearPCMIsFloatKey];
    //声道采样率
    [dicM setObject:@(AVAudioQualityMedium) forKey:AVSampleRateConverterAudioQualityKey];
    return dicM;
}

- (NSString *)outputFilePath{
    NSString *outputFileDir = [NSString stringWithFormat:@"%@/Library/outputAudio", NSHomeDirectory()];
    BOOL isDir = NO;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL existed = [fileManager fileExistsAtPath:outputFileDir isDirectory:&isDir];
    if (!(isDir == YES && existed == YES)){
        [fileManager createDirectoryAtPath:outputFileDir withIntermediateDirectories:YES attributes:nil error:nil];
    }
    NSString *filePath = [NSString stringWithFormat:@"%@/%@%@",outputFileDir,[[NSDate date].description stringByReplacingOccurrencesOfString:@" " withString:@"_"],@".caf"];
    NSLog(@"filePath create : %@",filePath);
    return filePath;
}

- (BOOL)checkAuthorization{
    BOOL allowed = NO;
    AVAuthorizationStatus audioAuthorizationStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (audioAuthorizationStatus == AVAuthorizationStatusAuthorized || audioAuthorizationStatus == AVAuthorizationStatusNotDetermined) {
        allowed = YES;
    }
    if (!allowed) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"请在iPhone的\"设置-隐私\"选项中，允许访问你的麦克风。" message:@"" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil];
        [alert show];
    }
    return allowed;
}

@end
