//
//  SendSmsViewController.swift
//  IceBox
//
//  Created by QSC on 16/7/27.
//  Copyright © 2016年 qsc. All rights reserved.
//

import UIKit
import MessageUI
import AddressBook
import AddressBookUI

class SendSmsViewController: UIViewController {

    @IBOutlet var phoneTextField: UITextField!
    @IBOutlet var companyTextField: UITextField!
    @IBOutlet var countTextField: UITextField!

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)

        checkContactsAuthorized()
    }

    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        super.touchesBegan(touches, withEvent: event)
        view.endEditing(true)
    }

    func checkContactsAuthorized() {
        var error:Unmanaged<CFError>?
        let addressBook: ABAddressBookRef? = ABAddressBookCreateWithOptions(nil, &error).takeRetainedValue()

        let sysAddressBookStatus = ABAddressBookGetAuthorizationStatus()

        if sysAddressBookStatus == .Denied || sysAddressBookStatus == .NotDetermined {
            // Need to ask for authorization
            let authorizedSingal:dispatch_semaphore_t = dispatch_semaphore_create(0)
            let askAuthorization:ABAddressBookRequestAccessCompletionHandler = { success, error in
                if success {
                    ABAddressBookCopyArrayOfAllPeople(addressBook).takeRetainedValue() as NSArray
                    dispatch_semaphore_signal(authorizedSingal)
                } else {
                    self.showMessage("访问联系人失败", message: "请确保您以允许此应用访问联系人")
                }
            }
            ABAddressBookRequestAccessWithCompletion(addressBook, askAuthorization)
            dispatch_semaphore_wait(authorizedSingal, DISPATCH_TIME_FOREVER)
        }
    }

    @IBAction func SelectContact(sender: AnyObject) {
        let picker = ABPeoplePickerNavigationController()
        picker.peoplePickerDelegate = self
        picker.displayedProperties = [NSNumber(int: kABPersonPhoneProperty)]
        picker.predicateForSelectionOfPerson = NSPredicate(format: "%K.@count < 2", ABPersonPhoneNumbersProperty)
        picker.predicateForEnablingPerson =  NSPredicate(format: "%K.@count > 0", ABPersonPhoneNumbersProperty)

        presentViewController(picker, animated: true) { 

        }
    }

    @IBAction func receiveAlertButtonTouched(sender: AnyObject) {
        sendSms(isSendBox: false)
    }

    @IBAction func sendButtonPressed(sender: AnyObject) {
        sendSms(isSendBox: true)
    }

    func sendSms(isSendBox isSend: Bool) {
        guard MFMessageComposeViewController.canSendText() else {
            log.error("can not send msg")
            showMessage("此设备不支持发送短信", message: nil)
            return
        }

        if phoneTextField.text?.characters.count < 1 {
            noticeError("请选择联系人或输入联系人号码！", autoClearTime: 1)
            return
        }

        let picker = MFMessageComposeViewController()
        var company = ""
        if let companyName = companyTextField.text {
            company = companyName + "的"
        }

        var countString = "0"
        if let count = countTextField.text where count.characters.count > 0 {
            countString = count
        }
        let msgBody = String(format: "尊敬的%@工作人员，您有%@件货物已经成功%@，请及时注意物流动向.", company, countString , isSend ? "发送" : "接收")

        picker.messageComposeDelegate = self
        picker.body = msgBody
        picker.recipients = [phoneTextField.text ?? ""]

        presentViewController(picker, animated: true) {
            log.debug("")
        }
    }

    func showMessage(title: String?, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        let action = UIAlertAction(title: "确认", style: .Default) { (action) in
            self.navigationController?.popViewControllerAnimated(true)
        }

        alert.addAction(action)
        self.presentViewController(alert, animated: true) {}
    }
}

extension SendSmsViewController: ABPeoplePickerNavigationControllerDelegate {
    func peoplePickerNavigationController(peoplePicker: ABPeoplePickerNavigationController, didSelectPerson person: ABRecord) {
        let phone: ABMultiValueRef = ABRecordCopyValue(person, kABPersonPhoneProperty).takeRetainedValue()
        if (ABMultiValueGetCount(phone) > 0) {
            let index = 0 as CFIndex
            let mobile = ABMultiValueCopyValueAtIndex(phone, index).takeRetainedValue() as! String
            log.info("mobile: \(mobile)")
            self.phoneTextField.text = mobile
        } else {
            log.info("user has no mobile")
        }
    }

    func peoplePickerNavigationController(peoplePicker: ABPeoplePickerNavigationController, didSelectPerson person: ABRecordRef, property: ABPropertyID, identifier: ABMultiValueIdentifier) {
        let multiValue: ABMultiValueRef = ABRecordCopyValue(person, property).takeRetainedValue()
        let index = ABMultiValueGetIndexForIdentifier(multiValue, identifier)
        let mobile = ABMultiValueCopyValueAtIndex(multiValue, index).takeRetainedValue() as! String
        self.phoneTextField.text = mobile

        log.info(mobile)
    }

    func peoplePickerNavigationControllerDidCancel(peoplePicker: ABPeoplePickerNavigationController) {
        log.info("canceled")
    }

    func checkPersonHasMultiNumber(person: ABRecord) -> Bool {
        let phone: ABMultiValueRef = ABRecordCopyValue(person, kABPersonPhoneProperty).takeRetainedValue()
        if (ABMultiValueGetCount(phone) > 1) {
            log.info("person have more than 1 number")
            return true
        }
        log.info("person have 1 or 0 number")
        return false
    }
}

extension SendSmsViewController: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(controller: MFMessageComposeViewController, didFinishWithResult result: MessageComposeResult) {
        controller.dismissViewControllerAnimated(true) { }
        log.debug("msg result: \(result)")        
        switch result {
        case MessageComposeResultSent:
            self.noticeSuccess("短信已发送！", autoClearTime: 1)
        case MessageComposeResultCancelled :
            self.noticeInfo("已取消短信发送！", autoClearTime: 1)
        case MessageComposeResultFailed:
            self.noticeError("短信发送失败！", autoClearTime: 1)
        default:
            log.error("")
            break
        }
    }
}
