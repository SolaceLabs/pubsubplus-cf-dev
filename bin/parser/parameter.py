from baseparameter import BaseParameter
import parametertypes
from solyaml import literal_unicode
from typing import Any, Dict, List, Optional, Union
from tileform import TileForm
from option import Option

class Parameter(BaseParameter):
    def __init__(self,
            name: str,
            *,
            pcfFormName: Optional[str]=None,
            defaultValue: Union[str, bool, int]=None,
            placeholder: Union[str, bool, int]=None,
            pcfType: Optional[str]=None,
            enumValues: Optional[List[Option]]=None,
            optional: Optional[bool]=None,
            tileForm: Optional[TileForm]=None,
            label: Optional[str]=None,
            parameterType: parametertypes.AbstractParameter=parametertypes.String
        )-> None:
        super().__init__(name, pcfFormName=pcfFormName, defaultValue=defaultValue, tileForm=tileForm, enumValues=enumValues, label=label, parameterType=parameterType)
        self.optional = optional
        self.placeholder = placeholder

    def generateTileTemplate(self, prefix: str, propertyListOutput, formOutput) -> None:
        fullName = prefix + "." + self.getPcfFormName() + "." + self.parameterType.pcfManifestType
        if self.name not in propertyListOutput:
            propertyListOutput[self.name] = []
        propertyListOutput[self.name].append(fullName)
        if formOutput and formOutput[-1]["name"] == self.getPcfFormName():
            if not self.parameterType.multiType:
                raise ValueError("parameter '" + self.getPcfFormName() + "' already seen in form output")
        else:
            formOutput.append(self.getFormRepresentation())

    def getFormRepresentation(self) -> Dict[str, Any]:
        output = super().getFormRepresentation()
        # if we have enum values then we store the default value in the option information
        if self.defaultValue is not None and self.enumValues is None:
            output["default"] = self.defaultValue
        if self.optional is not None:
            output["optional"] = self.optional
        if self.placeholder is not None:
            output["placeholder"] = self.placeholder
        if self.enumValues:
            output["options"] = []
            for value in self.enumValues:
                output["options"].append(value.getTileOptionRepresentation(self.defaultValue))
        return output

    def convertToBoshLiteManifest(self, fullPropertyName: str, relativePropertyName: str, propertyValue, outputProperties) -> None:
        self.parameterType.validate(propertyValue)
        if self.name not in outputProperties:
            assignValue = propertyValue
            if isinstance(propertyValue, dict):
                if self.parameterType.pcfManifestType in propertyValue:
                    assignValue = propertyValue[self.parameterType.pcfManifestType]
                else:
                    raise ValueError("property '" + fullPropertyName + "' expected type '" + self.parameterType.pcfManifestType + "' does not match described type(s) '" + str(propertyValue.keys()) + "'")
            if isinstance(assignValue, str):
                # Need to fix the newline issue when dumping yaml
                # long strings with newlines have to be marked as a literal block
                if "\n" in assignValue:
                    assignValue = literal_unicode(assignValue)
            outputProperties[self.name] = assignValue
        else:
            raise ValueError("property '" + self.name + "' already found in outputProperties")