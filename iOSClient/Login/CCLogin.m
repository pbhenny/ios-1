//
//  CCLogin.m
//  Crypto Cloud Technology Nextcloud
//
//  Created by Marino Faggiana on 09/04/15.
//  Copyright (c) 2014 TWS. All rights reserved.
//
//  Author Marino Faggiana <m.faggiana@twsweb.it>
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

#import "CCLogin.h"
#import "AppDelegate.h"
#import "CCUtility.h"
#import "CCCoreData.h"

@interface CCLogin ()
{
    UIAlertView *alertView;
    UIView *rootView;
}
@end

@implementation CCLogin

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (app.activeAccount.length > 0) {
        
        self.baseUrl.text = app.activeUrl;
        self.user.text = app.activeUser;
    }
    
    [self.baseUrl setDelegate:self];
    [self.password setDelegate:self];
    [self.user setDelegate:self];
    
    [self.baseUrl setFont:[UIFont systemFontOfSize:13]];
    [self.user setFont:[UIFont systemFontOfSize:13]];
    [self.password setFont:[UIFont systemFontOfSize:13]];
    
    self.loadingBaseUrl.image = [UIImage animatedImageWithAnimatedGIFURL:[[NSBundle mainBundle] URLForResource: @"loading" withExtension:@"gif"]];
    self.loadingBaseUrl.hidden = YES;
    
    if (_loginType == loginAdd) {
        
    }
    
    if (_loginType == loginAddForced) {
        _annulla.hidden = YES;
    }
    
    if (_loginType == loginModifyPasswordUser) {
        _baseUrl.userInteractionEnabled = NO;
        _baseUrl.textColor = [UIColor lightGrayColor];
        _user.userInteractionEnabled = NO;
        _user.textColor = [UIColor lightGrayColor];
    }
    
    [self.annulla setTitle:NSLocalizedString(@"_cancel_", nil) forState:UIControlStateNormal];
    [self.login setTitle:NSLocalizedString(@"_login_", nil) forState:UIControlStateNormal];
    
    [self.baseUrl setKeyboardType:UIKeyboardTypeURL];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    // verify URL
    if (_loginType == loginModifyPasswordUser && [self.baseUrl.text length] > 0)
        [self testUrl];
}

// E' apparsa
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self showIntro];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark ===== Intro =====
#pragma --------------------------------------------------------------------------------------------

- (void)showIntro
{
    if ([CCUtility getIntro:@"1.0"] == NO) {
        
        _intro = [[CCIntro alloc] initWithDelegate:self delegateView:self.view];
        [_intro showIntroCryptoCloud:2.0];
    }
}

- (void)introDidFinish:(EAIntroView *)introView wasSkipped:(BOOL)wasSkipped
{
    [CCUtility setIntro:@"1.0"];
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == Chech Server URL ==
#pragma --------------------------------------------------------------------------------------------

- (void)testUrl
{
    self.login.enabled = NO;
    self.loadingBaseUrl.hidden = NO;
    
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:self.baseUrl.text] cachePolicy:0 timeoutInterval:20.0];
    [request addValue:[CCUtility getUserAgent] forHTTPHeaderField:@"User-Agent"];
    
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:nil];
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler: ^(NSData *data, NSURLResponse *response, NSError *error) {
        
        dispatch_async(dispatch_get_main_queue(), ^{
            self.login.enabled = YES;
            self.loadingBaseUrl.hidden = YES;
        });

        if (error != nil) {
            
            NSLog(@"[LOG] Error: %ld - %@",(long)[error code] , [error localizedDescription]);
            
            // self signed certificate
            if ([error code] == NSURLErrorServerCertificateUntrusted) {
                
                NSLog(@"[LOG] Error NSURLErrorServerCertificateUntrusted");
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[CCCertificate sharedManager] presentViewControllerCertificateWithTitle:[error localizedDescription] viewController:self delegate:self];
                });
            
            } else {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_connection_error_",nil) message:[error localizedDescription] delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
                    [alertView show];
                    
                    if (_loginType != loginModifyPasswordUser)
                        self.baseUrl.text = @"";
                });
            }
            
        }
    }];
    
    [task resume];
}

- (void)trustedCerticateAccepted
{
    NSLog(@"[LOG] Certificate trusted");
}

- (void)trustedCerticateDenied
{
    if (_loginType == loginModifyPasswordUser)
        [self handleAnnulla:self];
}

-(void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler
{
    // The pinnning check
    
    if ([[CCCertificate sharedManager] checkTrustedChallenge:challenge]) {
        completionHandler(NSURLSessionAuthChallengeUseCredential, [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == Login ==
#pragma --------------------------------------------------------------------------------------------

- (void)loginCloud
{
    self.login.enabled = NO;
    self.loadingBaseUrl.hidden = NO;

    // remove last char if /
    if ([[self.baseUrl.text substringFromIndex:[self.baseUrl.text length] - 1] isEqualToString:@"/"])
        self.baseUrl.text = [self.baseUrl.text substringToIndex:[self.baseUrl.text length] - 1];
    
    OCnetworking *ocNet = [[OCnetworking alloc] initWithDelegate:self metadataNet:nil withUser:self.user.text withPassword:self.password.text withUrl:nil isCryptoCloudMode:NO];
    NSError *error = [ocNet readFileSync:[NSString stringWithFormat:@"%@%@", self.baseUrl.text, webDAV]];
    
    if (!error) {
        
        // account
        NSString *account = [NSString stringWithFormat:@"%@ %@", self.user.text, self.baseUrl.text];
        
        if (_loginType == loginModifyPasswordUser) {
            
            [CCCoreData updateAccount:account withPassword:self.password.text];
            
        } else {

            [CCCoreData deleteAccount:account];
        
            // Add default account
            [CCCoreData addAccount:account url:self.baseUrl.text user:self.user.text password:self.password.text];
        }
        
        TableAccount *tableAccount = [CCCoreData setActiveAccount:account];
        
        // verifica
        if ([tableAccount.account isEqualToString:account]) {
            
            [app settingActiveAccount:tableAccount.account activeUrl:tableAccount.url activeUser:tableAccount.user activePassword:tableAccount.password];
            
            [self.delegate loginSuccess:_loginType];
            
            // close
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [self dismissViewControllerAnimated:YES completion:nil];
            });
            
        } else {
            
            if (_loginType != loginModifyPasswordUser)
                [CCCoreData deleteAccount:account];
            
            alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:@"Fatal error writing database" delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
            [alertView show];
        }

    } else {
        
        if ([error code] != NSURLErrorServerCertificateUntrusted) {
            
            NSString *description = [error.userInfo objectForKey:@"NSLocalizedDescription"];
            NSString *message = [NSString stringWithFormat:@"%@.\n%@", NSLocalizedStringFromTable(@"_not_possible_connect_to_server_", @"Error", nil), description];
            
            alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"_error_", nil) message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:NSLocalizedString(@"_ok_", nil), nil];
            [alertView show];
        }
    }
        
    self.login.enabled = YES;
    self.loadingBaseUrl.hidden = YES;
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == TextField ==
#pragma --------------------------------------------------------------------------------------------

-(void)textFieldDidBeginEditing:(UITextField *)textField
{
    if (textField == self.password) {
        self.toggleVisiblePassword.hidden = NO;
        self.password.defaultTextAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f], NSForegroundColorAttributeName: [UIColor darkGrayColor]};
    }
}

-(void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == self.password) {
        self.toggleVisiblePassword.hidden = YES;
        self.password.defaultTextAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f], NSForegroundColorAttributeName: [UIColor darkGrayColor]};
    }
}

#pragma --------------------------------------------------------------------------------------------
#pragma mark == IBAction ==
#pragma --------------------------------------------------------------------------------------------

- (IBAction)handlebaseUrlchange:(id)sender
{
    if ([self.baseUrl.text length] > 0)
        [self performSelector:@selector(testUrl) withObject:nil];
}

- (IBAction)handleButtonLogin:(id)sender
{
    if ([self.baseUrl.text length] > 0 && [self.user.text length] && [self.password.text length])
        [self performSelector:@selector(loginCloud) withObject:nil];
}

- (IBAction)handleAnnulla:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)handleToggleVisiblePassword:(id)sender
{
    NSString *currentPassword = self.password.text;
    
    self.password.secureTextEntry = ! self.password.secureTextEntry;
    
    self.password.text = @"";
    self.password.text = currentPassword;
    self.password.defaultTextAttributes = @{NSFontAttributeName: [UIFont systemFontOfSize:14.0f], NSForegroundColorAttributeName: [UIColor darkGrayColor]};
}

@end
